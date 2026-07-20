package com.rmf.rdvp.archive.api;

import java.util.Base64;

import com.rmf.rdvp.archive.ArchiveImage;

public record ArchiveImageSummaryResponse(
        String id,
        int sortOrder,
        int width,
        int height,
        String thumbnailDataUri) {

    static ArchiveImageSummaryResponse from(ArchiveImage image) {
        return new ArchiveImageSummaryResponse(
                image.id(),
                image.sortOrder(),
                image.width(),
                image.height(),
                toDataUri(image.contentType(), image.thumbnail()));
    }

    static String toDataUri(String contentType, byte[] content) {
        return "data:%s;base64,%s".formatted(contentType, Base64.getEncoder().encodeToString(content));
    }
}
