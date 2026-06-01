package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record DeviceChangeRequest(
        String id,
        DeviceChangeRequestType type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantId,
        String applicantName,
        DeviceChangeRequestStatus status,
        String reason,
        Map<String, DeviceChangeValue> changes,
        OffsetDateTime createdAt,
        String reviewerId,
        String reviewComment,
        OffsetDateTime reviewedAt,
        OffsetDateTime freezeUntil) {
}
