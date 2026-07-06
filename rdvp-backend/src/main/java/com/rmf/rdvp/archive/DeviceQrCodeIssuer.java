package com.rmf.rdvp.archive;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.shared.config.RdvpRuntimeProperties;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;

@Service
public class DeviceQrCodeIssuer {

    static final String QR_PREFIX = "RDVP";
    static final int MAX_QR_VERSION = 999;

    private static final String QR_HMAC_ALGORITHM = "HmacSHA256";
    private static final String QR_STATUS_ACTIVE = "ACTIVE";

    private final DeviceQrCodeRepository qrCodeRepository;
    private final RdvpRuntimeProperties runtimeProperties;

    public DeviceQrCodeIssuer(
            DeviceQrCodeRepository qrCodeRepository,
            RdvpRuntimeProperties runtimeProperties) {
        this.qrCodeRepository = qrCodeRepository;
        this.runtimeProperties = runtimeProperties;
    }

    public DeviceQrCode findLatestActiveOrIssue(
            String deviceId,
            String deviceCode,
            OffsetDateTime issuedAt,
            String createdBy) {
        return qrCodeRepository.findLatestActiveByDeviceId(deviceId)
                .orElseGet(() -> issue(deviceId, deviceCode, issuedAt, createdBy));
    }

    public DeviceQrCode issueInitial(
            String deviceId,
            String deviceCode,
            OffsetDateTime issuedAt,
            String createdBy) {
        return issue(deviceId, deviceCode, issuedAt, createdBy);
    }

    public String buildQrContent(String deviceCode, DeviceQrCode qrCode) {
        return "%s:%d:%s:%s:%s".formatted(
                QR_PREFIX,
                qrCode.version(),
                deviceCode,
                qrCode.nonce(),
                qrCode.signatureHash());
    }

    public String buildSignature(int version, String deviceCode, String nonce) {
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

    private DeviceQrCode issue(
            String deviceId,
            String deviceCode,
            OffsetDateTime issuedAt,
            String createdBy) {
        int version = qrCodeRepository.nextVersionByDeviceId(deviceId);
        if (version <= 0 || version > MAX_QR_VERSION) {
            throw new BusinessException(ErrorCode.QR_CODE_INVALID, "QR code version limit exceeded.");
        }

        String nonce = "nonce-" + UUID.randomUUID();
        String signature = buildSignature(version, deviceCode, nonce);
        OffsetDateTime expiresAt = issuedAt.plusYears(1);
        DeviceQrCodeCreate create = new DeviceQrCodeCreate(
                "qrcode-" + UUID.randomUUID(),
                deviceId,
                version,
                nonce,
                signature,
                QR_STATUS_ACTIVE,
                issuedAt,
                expiresAt,
                createdBy);
        qrCodeRepository.create(create);
        return new DeviceQrCode(
                create.id(),
                create.deviceId(),
                create.version(),
                create.nonce(),
                create.signatureHash(),
                create.status(),
                create.expiresAt());
    }
}
