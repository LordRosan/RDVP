package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;

public record ReinspectionRecord(
        String id,
        String reinspectionRecordNo,
        String faultReportId,
        String repairReportId,
        String reinspectorId,
        ReinspectionResult result,
        OffsetDateTime reinspectedAt,
        String description,
        FaultStatus nextFaultStatus,
        String nextDeviceStatus,
        OffsetDateTime createdAt) {
}
