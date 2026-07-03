package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceArchiveRequest;

public record DeviceArchiveReviewResultResponse(
        String id,
        String status,
        String reviewedAt,
        String freezeUntil) {

    public static DeviceArchiveReviewResultResponse from(DeviceArchiveRequest request) {
        return new DeviceArchiveReviewResultResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.reviewedAt()),
                toIsoString(request.freezeUntil()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
