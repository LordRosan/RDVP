package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record DeviceVerificationReportCreate(
        String id,
        String deviceId,
        String operatorId,
        DeviceVerificationResult result,
        String description,
        String remark,
        OffsetDateTime verifiedAt,
        OffsetDateTime createdAt) {
}
