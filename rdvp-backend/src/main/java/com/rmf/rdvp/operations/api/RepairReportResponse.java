package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.RepairReportRecord;

public record RepairReportResponse(
        String id,
        String repairReportNo,
        String repairTaskId,
        String result,
        boolean requiresReinspection,
        String createdAt) {

    public static RepairReportResponse from(RepairReportRecord record) {
        return new RepairReportResponse(
                record.id(),
                record.repairReportNo(),
                record.repairTaskId(),
                record.result().name(),
                record.requiresReinspection(),
                record.createdAt().toString());
    }
}
