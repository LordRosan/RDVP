package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.FaultReportRecord;

public record FaultReportResponse(
        String id,
        String faultReportNo,
        String faultType,
        String faultSubtype,
        String status,
        String createdAt) {

    public static FaultReportResponse from(FaultReportRecord record) {
        return new FaultReportResponse(
                record.id(),
                record.faultReportNo(),
                record.faultType().name(),
                record.faultSubtype(),
                record.status().name(),
                record.createdAt().toString());
    }
}
