package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;

public record DeviceVerificationRecordCreate(
        String id,
        String deviceId,
        String operatorId,
        DeviceVerificationResult result,
        String description,
        String remark,
        OffsetDateTime verifiedAt,
        OffsetDateTime createdAt) {
}
