package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record DeviceArchiveChangeRequestCreate(
        String id,
        DeviceArchiveChangeRequestType type,
        String deviceId,
        String targetDeviceCode,
        String applicantId,
        String previousDeviceStatus,
        String reason,
        Map<String, DeviceArchiveChangeValue> changes,
        OffsetDateTime initiatedAt,
        OffsetDateTime createdAt) {
}
