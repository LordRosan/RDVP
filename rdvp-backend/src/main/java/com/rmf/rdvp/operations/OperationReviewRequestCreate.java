package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record OperationReviewRequestCreate(
        String id,
        OperationReviewRequestType type,
        String targetId,
        String targetNo,
        String faultReportId,
        String deviceId,
        String applicantId,
        String summary,
        OffsetDateTime submittedAt,
        OffsetDateTime createdAt) {
}
