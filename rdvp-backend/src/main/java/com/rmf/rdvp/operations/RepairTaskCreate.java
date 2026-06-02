package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record RepairTaskCreate(
        String id,
        String repairTaskNo,
        String faultReportId,
        String maintainerId,
        BigDecimal acceptedLongitude,
        BigDecimal acceptedLatitude,
        OffsetDateTime acceptedAt) {
}
