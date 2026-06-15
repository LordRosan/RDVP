package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceArchiveChangeRequest;

public record DeviceArchiveReviewResultResponse(
        String id,
        String status,
        String reviewedAt,
        String freezeUntil) {

    public static DeviceArchiveReviewResultResponse from(DeviceArchiveChangeRequest request) {
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
