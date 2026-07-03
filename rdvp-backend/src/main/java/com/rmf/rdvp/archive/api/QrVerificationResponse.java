package com.rmf.rdvp.archive.api;

import com.rmf.rdvp.archive.DeviceArchiveService;

public record QrVerificationResponse(
        boolean valid,
        DeviceArchiveResponse device) {

    public static QrVerificationResponse from(DeviceArchiveService.QrVerificationResult result) {
        return new QrVerificationResponse(result.valid(), DeviceArchiveResponse.from(result.device()));
    }
}
