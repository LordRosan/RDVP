package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record RepairTaskRecord(
        String id,
        String repairTaskNo,
        String faultReportId,
        String deviceId,
        String maintainerId,
        FaultSeverity severity,
        RepairTaskStatus status,
        BigDecimal acceptedLongitude,
        BigDecimal acceptedLatitude,
        OffsetDateTime acceptedAt,
        OffsetDateTime completedAt) {
}
