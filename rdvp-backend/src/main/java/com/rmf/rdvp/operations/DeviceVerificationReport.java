package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;
import java.util.List;

public record DeviceVerificationReport(
        String id,
        String deviceId,
        String operatorId,
        VerificationType verificationType,
        VerificationDeviceStatus deviceStatus,
        VerificationMethod verificationMethod,
        DeviceVerificationResult result,
        List<DeviceVerificationReportItem> items,
        String description,
        String remark,
        OffsetDateTime verifiedAt,
        OffsetDateTime createdAt) {
}
