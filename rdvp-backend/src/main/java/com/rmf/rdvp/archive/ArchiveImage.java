package com.rmf.rdvp.archive;

public record ArchiveImage(
        String id,
        String deviceId,
        int sortOrder,
        String contentType,
        int width,
        int height,
        byte[] content,
        byte[] thumbnail) {
}
