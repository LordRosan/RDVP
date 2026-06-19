package com.rmf.rdvp.api.archive;

public record DeviceArchiveExportVerificationResponse(
        boolean verified,
        String deviceId,
        String deviceCode) {
}
