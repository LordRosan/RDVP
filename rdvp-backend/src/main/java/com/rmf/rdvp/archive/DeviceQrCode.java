package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;

public record DeviceQrCode(
        String id,
        String deviceId,
        int version,
        String nonce,
        String signatureHash,
        String status,
        OffsetDateTime expiresAt) {
}
