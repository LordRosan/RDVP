package com.rmf.rdvp.archive.api;

public record DeviceArchiveExportVerificationResponse(
        boolean verified,
        String deviceId,
        String deviceCode) {
}
