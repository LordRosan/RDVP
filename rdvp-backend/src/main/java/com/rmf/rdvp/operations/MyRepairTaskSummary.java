package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record MyRepairTaskSummary(
        String id,
        String repairTaskNo,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        FaultType faultType,
        FaultSeverity severity,
        OffsetDateTime acceptedAt,
        RepairTaskStatus status) {
}
