package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record FaultReportRecord(
        String id,
        String faultReportNo,
        String deviceId,
        String reporterId,
        FaultType faultType,
        String faultSubtype,
        FaultSeverity severity,
        FaultStatus status,
        String description,
        String sceneCondition,
        OffsetDateTime occurredAt,
        BigDecimal longitude,
        BigDecimal latitude,
        String acceptedTaskId,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {
}
