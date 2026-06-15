package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record ReinspectionTaskSummary(
        String id,
        String faultReportId,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        FaultSeverity severity,
        RepairTaskPoolItem.DeviceLocation location,
        OffsetDateTime repairedAt,
        FaultStatus status) {
}
