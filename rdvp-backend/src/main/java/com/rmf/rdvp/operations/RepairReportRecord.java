package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record RepairReportRecord(
        String id,
        String repairReportNo,
        String repairTaskId,
        String faultReportId,
        String maintainerId,
        RepairReportResult result,
        OffsetDateTime repairedAt,
        String processDescription,
        String partsUsed,
        boolean requiresReinspection,
        OffsetDateTime createdAt) {
}
