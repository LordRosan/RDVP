package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;

public record DeviceQrCodeExport(
        String deviceId,
        String deviceCode,
        String fileName,
        String qrImageBase64,
        String qrContentDigest,
        OffsetDateTime exportedAt) {
}
