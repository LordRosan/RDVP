package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;

public record DeviceQrCodeCreate(
        String id,
        String deviceId,
        int version,
        String nonce,
        String signatureHash,
        String status,
        OffsetDateTime issuedAt,
        OffsetDateTime expiresAt,
        String createdBy) {
}
