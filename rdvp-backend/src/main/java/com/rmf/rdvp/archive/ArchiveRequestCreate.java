package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record ArchiveRequestCreate(
        String id,
        ArchiveRequestType type,
        String deviceId,
        String targetDeviceCode,
        String applicantId,
        String previousDeviceStatus,
        String reason,
        Map<String, ArchiveFieldChange> changes,
        OffsetDateTime initiatedAt,
        OffsetDateTime createdAt) {
}
