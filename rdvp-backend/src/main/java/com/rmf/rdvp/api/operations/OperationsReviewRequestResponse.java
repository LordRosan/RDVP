package com.rmf.rdvp.api.operations;

import java.time.OffsetDateTime;

import com.rmf.rdvp.operations.OperationsReviewRequest;

public record OperationsReviewRequestResponse(
        String id,
        String type,
        String targetId,
        String targetNo,
        String faultReportId,
        String deviceId,
        String deviceCode,
        String deviceName,
        String operatorId,
        String operatorName,
        String summary,
        String status,
        String submittedAt,
        String reviewOperatorId,
        String reviewComment,
        String reviewedAt) {

    public static OperationsReviewRequestResponse from(OperationsReviewRequest request) {
        return new OperationsReviewRequestResponse(
                request.id(),
                request.type().name(),
                request.targetId(),
                request.targetNo(),
                request.faultReportId(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.operatorId(),
                request.operatorName(),
                request.summary(),
                request.status().name(),
                toIsoString(request.submittedAt()),
                request.reviewOperatorId(),
                request.reviewComment(),
                toIsoString(request.reviewedAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
