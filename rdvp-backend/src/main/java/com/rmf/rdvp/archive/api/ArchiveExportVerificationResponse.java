package com.rmf.rdvp.archive.api;

public record ArchiveExportVerificationResponse(
        boolean verified,
        String deviceId,
        String deviceCode) {
}
