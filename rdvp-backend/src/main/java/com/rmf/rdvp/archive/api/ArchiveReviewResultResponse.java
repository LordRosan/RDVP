package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.ArchiveRequest;

public record ArchiveReviewResultResponse(
        String id,
        String status,
        String reviewedAt,
        String freezeUntil) {

    public static ArchiveReviewResultResponse from(ArchiveRequest request) {
        return new ArchiveReviewResultResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.reviewedAt()),
                toIsoString(request.freezeUntil()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
