package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record DeviceArchiveChangeRequest(
        String id,
        DeviceArchiveChangeRequestType type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantId,
        String applicantName,
        DeviceArchiveChangeRequestStatus status,
        String reason,
        Map<String, DeviceArchiveChangeValue> changes,
        OffsetDateTime initiatedAt,
        OffsetDateTime createdAt,
        String reviewerId,
        String reviewComment,
        OffsetDateTime reviewedAt,
        OffsetDateTime freezeUntil) {
}
