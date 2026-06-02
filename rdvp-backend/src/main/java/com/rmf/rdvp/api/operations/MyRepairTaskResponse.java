package com.rmf.rdvp.api.operations;

import com.rmf.rdvp.operations.MyRepairTaskSummary;

public record MyRepairTaskResponse(
        String id,
        String repairTaskNo,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        String faultType,
        String severity,
        String acceptedAt,
        String status) {

    public static MyRepairTaskResponse from(MyRepairTaskSummary item) {
        return new MyRepairTaskResponse(
                item.id(),
                item.repairTaskNo(),
                item.faultReportNo(),
                item.deviceCode(),
                item.deviceName(),
                item.faultType().name(),
                item.severity().name(),
                item.acceptedAt().toString(),
                item.status().name());
    }
}
