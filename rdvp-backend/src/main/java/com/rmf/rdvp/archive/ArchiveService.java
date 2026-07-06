package com.rmf.rdvp.archive;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Locale;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryService;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticatedUser;

@Service
public class ArchiveService {

    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Pattern DEVICE_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final Pattern QR_NONCE_PATTERN = Pattern.compile("^[A-Za-z0-9._-]{1,128}$");
    private static final Pattern QR_SIGNATURE_PATTERN = Pattern.compile("^[0-9a-fA-F]{64}$");
    private static final int QR_EXPORT_IMAGE_SIZE = 512;

    private final ArchiveRepository archiveRepository;
    private final DeviceQrCodeRepository qrCodeRepository;
    private final DeviceQrCodeIssuer qrCodeIssuer;
    private final LogEntryService logEntryService;

    public ArchiveService(
            ArchiveRepository archiveRepository,
            DeviceQrCodeRepository qrCodeRepository,
            DeviceQrCodeIssuer qrCodeIssuer,
            LogEntryService logEntryService) {
        this.archiveRepository = archiveRepository;
        this.qrCodeRepository = qrCodeRepository;
        this.qrCodeIssuer = qrCodeIssuer;
        this.logEntryService = logEntryService;
    }

    public Archive findByCode(String deviceCode) {
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        return archiveRepository.findByCode(normalizedDeviceCode)
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
    }

    public Archive findById(String deviceId) {
        if (deviceId == null || !DEVICE_ID_PATTERN.matcher(deviceId.trim()).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "deviceId is required.");
        }

        return archiveRepository.findById(deviceId.trim())
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
    }

    public boolean existsByCode(String deviceCode) {
        return archiveRepository.existsByCode(normalizeDeviceCode(deviceCode));
    }

    public QrVerificationResult verifyQrCode(String qrContent) {
        ParsedQrContent parsed = parseQrContent(qrContent);
        Archive device = archiveRepository.findByCode(parsed.deviceCode())
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

        String expectedSignature = qrCodeIssuer.buildSignature(parsed.version(), parsed.deviceCode(), parsed.nonce());
        if (!constantTimeEquals(parsed.signature(), expectedSignature)
                || !constantTimeEquals(parsed.signature(), qrCode.signatureHash())) {
            throw new BusinessException(ErrorCode.QR_CODE_SIGNATURE_INVALID);
        }

        return new QrVerificationResult(true, device);
    }

    public DeviceQrCodeExport exportQrCode(String deviceId, AuthenticatedUser operator) {
        Archive device = null;
        try {
            device = findById(deviceId);
            OffsetDateTime exportedAt = OffsetDateTime.now(ZoneOffset.UTC);
            DeviceQrCode qrCode = qrCodeIssuer.findLatestActiveOrIssue(
                    device.id(),
                    device.deviceCode(),
                    exportedAt,
                    operator.id());
            String qrContent = qrCodeIssuer.buildQrContent(device.deviceCode(), qrCode);
            DeviceQrCodeExport export = new DeviceQrCodeExport(
                    device.id(),
                    device.deviceCode(),
                    device.deviceCode() + ".png",
                    generateQrPngBase64(qrContent),
                    sha256Hex(qrContent),
                    exportedAt);
            logEntryService.recordSuccess(
                    LogAction.ARCHIVE_EXPORT,
                    device.id(),
                    device.deviceCode(),
                    operator,
                    "导出设备二维码。");
            return export;
        } catch (BusinessException exception) {
            logEntryService.recordFailure(
                    LogAction.ARCHIVE_EXPORT,
                    device == null ? normalizeLogTarget(deviceId) : device.id(),
                    device == null ? normalizeLogTarget(deviceId) : device.deviceCode(),
                    operator,
                    "设备二维码导出失败：%s。".formatted(exception.getErrorCode().code()));
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
        if (segments.length != 5 || !DeviceQrCodeIssuer.QR_PREFIX.equals(segments[0])) {
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
                || version > DeviceQrCodeIssuer.MAX_QR_VERSION
                || !QR_NONCE_PATTERN.matcher(nonce).matches()
                || !QR_SIGNATURE_PATTERN.matcher(signature).matches()) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID);
        }

        return new ParsedQrContent(version, normalizeDeviceCode(segments[2]), nonce, signature.toLowerCase(Locale.ROOT));
    }

    private String generateQrPngBase64(String content) {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            BitMatrix matrix = new MultiFormatWriter().encode(
                    content,
                    BarcodeFormat.QR_CODE,
                    QR_EXPORT_IMAGE_SIZE,
                    QR_EXPORT_IMAGE_SIZE);
            MatrixToImageWriter.writeToStream(matrix, "PNG", output);
            return Base64.getEncoder().encodeToString(output.toByteArray());
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private boolean constantTimeEquals(String left, String right) {
        byte[] leftBytes = left.getBytes(StandardCharsets.UTF_8);
        byte[] rightBytes = right.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(leftBytes, rightBytes);
    }

    private String normalizeLogTarget(String value) {
        String normalized = value == null ? "" : value.trim();
        return normalized.isBlank() ? null : normalized;
    }

    private record ParsedQrContent(int version, String deviceCode, String nonce, String signature) {
    }

    public record QrVerificationResult(boolean valid, Archive device) {
    }
}
