package com.rmf.rdvp.archive.api;

import com.rmf.rdvp.archive.ArchiveImage;

public record ArchiveImageContentResponse(
        String id,
        int width,
        int height,
        String dataUri) {

    public static ArchiveImageContentResponse from(ArchiveImage image) {
        return new ArchiveImageContentResponse(
                image.id(),
                image.width(),
                image.height(),
                ArchiveImageSummaryResponse.toDataUri(image.contentType(), image.content()));
    }
}
