package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record RepairTaskAcceptResult(
        String repairTaskId,
        String faultReportId,
        RepairTaskStatus status,
        OffsetDateTime acceptedAt) {
}
