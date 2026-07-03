package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.ArchiveRequest;

public record ArchiveRequestCreateResponse(
        String id,
        String status,
        String createdAt) {

    public static ArchiveRequestCreateResponse from(ArchiveRequest request) {
        return new ArchiveRequestCreateResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.createdAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
