package com.rmf.rdvp.api.operations;

import com.rmf.rdvp.operations.RepairTaskItem;

public record RepairTaskItemResponse(
        String id,
        String repairTaskNo,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        String faultType,
        String severity,
        String acceptedAt,
        String status) {

    public static RepairTaskItemResponse from(RepairTaskItem item) {
        return new RepairTaskItemResponse(
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
