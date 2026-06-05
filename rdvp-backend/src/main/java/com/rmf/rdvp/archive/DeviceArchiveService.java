package com.rmf.rdvp.archive;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.UUID;
import java.util.regex.Pattern;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.config.RdvpRuntimeProperties;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;

@Service
public class DeviceArchiveService {

    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Pattern DEVICE_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final Pattern QR_NONCE_PATTERN = Pattern.compile("^[A-Za-z0-9._-]{1,128}$");
    private static final Pattern QR_SIGNATURE_PATTERN = Pattern.compile("^[0-9a-fA-F]{64}$");
    private static final String QR_PREFIX = "RDVP";
    private static final String QR_HMAC_ALGORITHM = "HmacSHA256";
    private static final int MAX_QR_VERSION = 999;
    private static final int MAX_VERIFICATION_DESCRIPTION_LENGTH = 500;
    private static final int MAX_VERIFICATION_REMARK_LENGTH = 300;
    private static final DateTimeFormatter LOCAL_DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceQrCodeRepository qrCodeRepository;
    private final DeviceVerificationRepository verificationRepository;
    private final RdvpRuntimeProperties runtimeProperties;
    private final AuditLogService auditLogService;

    public DeviceArchiveService(
            DeviceArchiveRepository archiveRepository,
            DeviceQrCodeRepository qrCodeRepository,
            DeviceVerificationRepository verificationRepository,
            RdvpRuntimeProperties runtimeProperties,
            AuditLogService auditLogService) {
        this.archiveRepository = archiveRepository;
        this.qrCodeRepository = qrCodeRepository;
        this.verificationRepository = verificationRepository;
        this.runtimeProperties = runtimeProperties;
        this.auditLogService = auditLogService;
    }

    public DeviceArchive findByCode(String deviceCode) {
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        return archiveRepository.findByCode(normalizedDeviceCode)
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
    }

    public DeviceArchive findById(String deviceId) {
        if (deviceId == null || !DEVICE_ID_PATTERN.matcher(deviceId.trim()).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "deviceId is required.");
        }

        return archiveRepository.findById(deviceId.trim())
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
    }

    public QrVerificationResult verifyQrCode(String qrContent) {
        ParsedQrContent parsed = parseQrContent(qrContent);
        DeviceArchive device = archiveRepository.findByCode(parsed.deviceCode())
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        DeviceQrCode qrCode = qrCodeRepository
                .findByDeviceIdAndVersionAndNonce(device.id(), parsed.version(), parsed.nonce())
                .orElseThrow(() -> new BusinessException(ErrorCode.QR_CODE_INVALID));

        if ("REVOKED".equals(qrCode.status())) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID);
        }

        if ("EXPIRED".equals(qrCode.status())
                || (qrCode.expiresAt() != null && !qrCode.expiresAt().isAfter(OffsetDateTime.now()))) {
            throw new BusinessException(ErrorCode.QR_CODE_EXPIRED);
        }

        String expectedSignature = buildSignature(parsed.version(), parsed.deviceCode(), parsed.nonce());
        if (!constantTimeEquals(parsed.signature(), expectedSignature)
                || !constantTimeEquals(parsed.signature(), qrCode.signatureHash())) {
            throw new BusinessException(ErrorCode.QR_CODE_SIGNATURE_INVALID);
        }

        return new QrVerificationResult(true, device);
    }

    @Transactional
    public DeviceVerificationRecord createVerificationRecord(
            String deviceId,
            DeviceVerificationResult result,
            String description,
            String remark,
            String verifiedAt,
            AuthenticatedUser operator) {
        DeviceArchive device = null;
        try {
            device = findById(deviceId);
            OffsetDateTime normalizedVerifiedAt = parseDateTime(verifiedAt, "verifiedAt");
            OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
            DeviceVerificationRecordCreate create = new DeviceVerificationRecordCreate(
                    "verification-" + UUID.randomUUID(),
                    device.id(),
                    operator.id(),
                    requireVerificationResult(result),
                    normalizeRequiredText(
                            description,
                            "description",
                            MAX_VERIFICATION_DESCRIPTION_LENGTH,
                            ErrorCode.DEVICE_VERIFICATION_INVALID),
                    normalizeOptionalText(
                            remark,
                            MAX_VERIFICATION_REMARK_LENGTH,
                            ErrorCode.DEVICE_VERIFICATION_INVALID),
                    normalizedVerifiedAt,
                    now);

            verificationRepository.create(create);
            archiveRepository.updateLastVerificationTime(device.id(), normalizedVerifiedAt, operator.id());
            DeviceVerificationRecord record = verificationRepository.findById(create.id())
                    .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR));
            auditLogService.recordSuccess(
                    AuditAction.DEVICE_VERIFICATION,
                    record.id(),
                    device.deviceCode(),
                    operator,
                    "Submitted device verification record.");
            return record;
        } catch (BusinessException exception) {
            recordDeviceVerificationFailure(deviceId, device, operator, exception);
            throw exception;
        }
    }

    private String normalizeDeviceCode(String deviceCode) {
        if (deviceCode == null) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_INVALID);
        }

        String normalizedDeviceCode = deviceCode.trim().toUpperCase();
        if (!DEVICE_CODE_PATTERN.matcher(normalizedDeviceCode).matches()) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_INVALID);
        }

        return normalizedDeviceCode;
    }

    private ParsedQrContent parseQrContent(String qrContent) {
        if (qrContent == null || qrContent.isBlank()) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID);
        }

        String[] segments = qrContent.trim().split(":", -1);
        if (segments.length != 5 || !QR_PREFIX.equals(segments[0])) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID);
        }

        int version;
        try {
            version = Integer.parseInt(segments[1]);
        } catch (NumberFormatException exception) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID);
        }

        String signature = segments[4].trim();
        String nonce = segments[3].trim();
        if (version <= 0
                || version > MAX_QR_VERSION
                || !QR_NONCE_PATTERN.matcher(nonce).matches()
                || !QR_SIGNATURE_PATTERN.matcher(signature).matches()) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID);
        }

        return new ParsedQrContent(version, normalizeDeviceCode(segments[2]), nonce, signature.toLowerCase(Locale.ROOT));
    }

    private String buildSignature(int version, String deviceCode, String nonce) {
        try {
            Mac mac = Mac.getInstance(QR_HMAC_ALGORITHM);
            SecretKeySpec key = new SecretKeySpec(
                    runtimeProperties.getQrCode().getSigningSecret().getBytes(StandardCharsets.UTF_8),
                    QR_HMAC_ALGORITHM);
            mac.init(key);
            byte[] digest = mac.doFinal("%d:%s:%s".formatted(version, deviceCode, nonce).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private OffsetDateTime parseDateTime(String value, String field) {
        String normalized = normalizeRequiredText(value, field, 64, ErrorCode.BAD_REQUEST);
        try {
            return OffsetDateTime.parse(normalized);
        } catch (DateTimeParseException ignored) {
        }

        try {
            return LocalDateTime.parse(normalized, LOCAL_DATE_TIME_FORMATTER).atOffset(ZoneOffset.UTC);
        } catch (DateTimeParseException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }

    private DeviceVerificationResult requireVerificationResult(DeviceVerificationResult result) {
        if (result == null) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "result is invalid.");
        }

        return result;
    }

    private String normalizeRequiredText(String value, String field, int maxLength, ErrorCode errorCode) {
        String normalized = normalizeOptionalText(value, maxLength, errorCode);
        if (normalized.isBlank()) {
            throw new BusinessException(errorCode, field + " is required.");
        }

        return normalized;
    }

    private String normalizeOptionalText(String value, int maxLength, ErrorCode errorCode) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.length() > maxLength) {
            throw new BusinessException(errorCode, "Text field must not exceed " + maxLength + " characters.");
        }

        return normalized;
    }

    private boolean constantTimeEquals(String left, String right) {
        byte[] leftBytes = left.getBytes(StandardCharsets.UTF_8);
        byte[] rightBytes = right.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(leftBytes, rightBytes);
    }

    private void recordDeviceVerificationFailure(
            String deviceId,
            DeviceArchive device,
            AuthenticatedUser operator,
            BusinessException exception) {
        auditLogService.recordFailure(
                AuditAction.DEVICE_VERIFICATION,
                device == null ? normalizeAuditTarget(deviceId) : device.id(),
                device == null ? normalizeAuditTarget(deviceId) : device.deviceCode(),
                operator,
                "设备核验提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private String normalizeAuditTarget(String value) {
        String normalized = value == null ? "" : value.trim();
        return normalized.isBlank() ? null : normalized;
    }

    private record ParsedQrContent(int version, String deviceCode, String nonce, String signature) {
    }

    public record QrVerificationResult(boolean valid, DeviceArchive device) {
    }
}
