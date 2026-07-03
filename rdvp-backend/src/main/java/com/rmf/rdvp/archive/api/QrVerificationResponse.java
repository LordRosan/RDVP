package com.rmf.rdvp.archive.api;

import com.rmf.rdvp.archive.ArchiveService;

public record QrVerificationResponse(
        boolean valid,
        ArchiveResponse device) {

    public static QrVerificationResponse from(ArchiveService.QrVerificationResult result) {
        return new QrVerificationResponse(result.valid(), ArchiveResponse.from(result.device()));
    }
}
