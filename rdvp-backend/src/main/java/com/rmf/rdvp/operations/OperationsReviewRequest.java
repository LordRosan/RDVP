package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record OperationsReviewRequest(
        String id,
        OperationsReviewRequestType type,
        String targetId,
        String targetNo,
        String faultReportId,
        String deviceId,
        String deviceCode,
        String deviceName,
        String operatorId,
        String operatorName,
        String summary,
        OperationsReviewRequestStatus status,
        OffsetDateTime submittedAt,
        String reviewerId,
        String reviewComment,
        OffsetDateTime reviewedAt) {
}
