package com.rmf.rdvp.api.operations;

import java.time.OffsetDateTime;

import com.rmf.rdvp.operations.OperationsReviewRequest;

public record OperationsReviewResultResponse(
        String id,
        String status,
        String reviewedAt) {

    public static OperationsReviewResultResponse from(OperationsReviewRequest request) {
        return new OperationsReviewResultResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.reviewedAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
