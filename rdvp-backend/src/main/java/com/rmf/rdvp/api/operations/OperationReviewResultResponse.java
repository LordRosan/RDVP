package com.rmf.rdvp.api.operations;

import java.time.OffsetDateTime;

import com.rmf.rdvp.operations.OperationReviewRequest;

public record OperationReviewResultResponse(
        String id,
        String status,
        String reviewedAt) {

    public static OperationReviewResultResponse from(OperationReviewRequest request) {
        return new OperationReviewResultResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.reviewedAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
