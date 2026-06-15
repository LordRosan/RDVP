package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record RepairTaskPoolItem(
        String id,
        String faultReportId,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        FaultType faultType,
        FaultSeverity severity,
        BigDecimal distanceKm,
        DeviceLocation location,
        OffsetDateTime submittedAt,
        RepairTaskStatus status,
        String taskType) {

    public record DeviceLocation(
            String address,
            BigDecimal longitude,
            BigDecimal latitude) {
    }
}
