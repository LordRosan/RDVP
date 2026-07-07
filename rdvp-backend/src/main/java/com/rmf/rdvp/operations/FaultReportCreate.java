package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record FaultReportCreate(
        String id,
        String faultReportNo,
        String deviceId,
        String reporterId,
        FaultType faultType,
        String faultSubtype,
        FaultSeverity severity,
        String description,
        String sceneCondition,
        OffsetDateTime occurredAt,
        BigDecimal longitude,
        BigDecimal latitude,
        OffsetDateTime createdAt) {
}
