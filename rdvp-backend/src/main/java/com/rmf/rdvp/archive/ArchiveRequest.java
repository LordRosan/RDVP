package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record ArchiveRequest(
        String id,
        ArchiveRequestType type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantId,
        String applicantName,
        ArchiveRequestStatus status,
        String reason,
        Map<String, ArchiveFieldChange> changes,
        OffsetDateTime initiatedAt,
        OffsetDateTime createdAt,
        String reviewerId,
        String reviewComment,
        OffsetDateTime reviewedAt,
        OffsetDateTime freezeUntil) {
}
