package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record DeviceArchiveRequestCreate(
        String id,
        DeviceArchiveRequestType type,
        String deviceId,
        String targetDeviceCode,
        String applicantId,
        String previousDeviceStatus,
        String reason,
        Map<String, DeviceArchiveFieldChange> changes,
        OffsetDateTime initiatedAt,
        OffsetDateTime createdAt) {
}
