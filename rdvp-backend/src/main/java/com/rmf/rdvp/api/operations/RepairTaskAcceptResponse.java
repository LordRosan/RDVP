package com.rmf.rdvp.api.operations;

import com.rmf.rdvp.operations.RepairTaskAcceptResult;

public record RepairTaskAcceptResponse(
        String repairTaskId,
        String faultReportId,
        String status,
        String acceptedAt) {

    public static RepairTaskAcceptResponse from(RepairTaskAcceptResult result) {
        return new RepairTaskAcceptResponse(
                result.repairTaskId(),
                result.faultReportId(),
                result.status().name(),
                result.acceptedAt().toString());
    }
}
