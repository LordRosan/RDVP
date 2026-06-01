package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceChangeRequest;

public record DeviceChangeReviewResultResponse(
        String id,
        String status,
        String reviewedAt,
        String freezeUntil) {

    public static DeviceChangeReviewResultResponse from(DeviceChangeRequest request) {
        return new DeviceChangeReviewResultResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.reviewedAt()),
                toIsoString(request.freezeUntil()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
