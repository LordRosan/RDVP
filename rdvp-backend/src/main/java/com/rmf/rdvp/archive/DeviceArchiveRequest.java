package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record DeviceArchiveRequest(
        String id,
        DeviceArchiveRequestType type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantId,
        String applicantName,
        DeviceArchiveRequestStatus status,
        String reason,
        Map<String, DeviceArchiveFieldChange> changes,
        OffsetDateTime initiatedAt,
        OffsetDateTime createdAt,
        String reviewerId,
        String reviewComment,
        OffsetDateTime reviewedAt,
        OffsetDateTime freezeUntil) {
}
