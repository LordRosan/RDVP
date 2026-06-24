package com.rmf.rdvp.api.operations;

import java.time.OffsetDateTime;

import com.rmf.rdvp.operations.OperationReviewRequest;

public record OperationReviewRequestResponse(
        String id,
        String type,
        String targetId,
        String targetNo,
        String faultReportId,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantId,
        String applicantName,
        String summary,
        String status,
        String submittedAt,
        String reviewerId,
        String reviewComment,
        String reviewedAt) {

    public static OperationReviewRequestResponse from(OperationReviewRequest request) {
        return new OperationReviewRequestResponse(
                request.id(),
                request.type().name(),
                request.targetId(),
                request.targetNo(),
                request.faultReportId(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                request.summary(),
                request.status().name(),
                toIsoString(request.submittedAt()),
                request.reviewerId(),
                request.reviewComment(),
                toIsoString(request.reviewedAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
