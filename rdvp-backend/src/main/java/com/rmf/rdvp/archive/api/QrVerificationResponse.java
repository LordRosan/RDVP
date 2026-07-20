package com.rmf.rdvp.archive.api;

import java.util.List;

import com.rmf.rdvp.archive.ArchiveImage;
import com.rmf.rdvp.archive.ArchiveService;

public record QrVerificationResponse(
        boolean valid,
        ArchiveResponse device) {

    public static QrVerificationResponse from(ArchiveService.QrVerificationResult result) {
        return from(result, List.of());
    }

    public static QrVerificationResponse from(
            ArchiveService.QrVerificationResult result,
            List<ArchiveImage> images) {
        return new QrVerificationResponse(result.valid(), ArchiveResponse.from(result.device(), images));
    }
}
