package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record OperationsReviewRequestCreate(
        String id,
        OperationsReviewRequestType type,
        String targetId,
        String targetNo,
        String faultReportId,
        String deviceId,
        String operatorId,
        String summary,
        OffsetDateTime submittedAt,
        OffsetDateTime createdAt) {
}
