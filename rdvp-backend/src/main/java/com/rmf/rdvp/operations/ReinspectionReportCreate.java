package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record ReinspectionReportCreate(
        String id,
        String reinspectionReportNo,
        String faultReportId,
        String repairReportId,
        String reinspectorId,
        ReinspectionResult result,
        OffsetDateTime reinspectedAt,
        String description,
        OffsetDateTime createdAt) {
}
