package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record OperationReviewRequest(
        String id,
        OperationReviewRequestType type,
        String targetId,
        String targetNo,
        String faultReportId,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantId,
        String applicantName,
        String summary,
        OperationReviewRequestStatus status,
        OffsetDateTime submittedAt,
        String reviewerId,
        String reviewComment,
        OffsetDateTime reviewedAt) {
}
