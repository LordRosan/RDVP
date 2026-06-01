package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Map;

public record DeviceChangeRequestCreate(
        String id,
        DeviceChangeRequestType type,
        String deviceId,
        String targetDeviceCode,
        String applicantId,
        String previousDeviceStatus,
        String reason,
        Map<String, DeviceChangeValue> changes,
        OffsetDateTime createdAt) {
}
