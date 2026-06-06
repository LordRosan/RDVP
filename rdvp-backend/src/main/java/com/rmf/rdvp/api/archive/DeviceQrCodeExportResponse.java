package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceQrCodeExport;

public record DeviceQrCodeExportResponse(
        String deviceId,
        String deviceCode,
        String fileName,
        String qrImageBase64,
        String qrContentDigest,
        OffsetDateTime exportedAt) {

    public static DeviceQrCodeExportResponse from(DeviceQrCodeExport export) {
        return new DeviceQrCodeExportResponse(
                export.deviceId(),
                export.deviceCode(),
                export.fileName(),
                export.qrImageBase64(),
                export.qrContentDigest(),
                export.exportedAt());
    }
}
