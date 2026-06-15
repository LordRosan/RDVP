package com.rmf.rdvp.api.operations;

import com.rmf.rdvp.operations.AcceptedRepairTaskItem;

public record AcceptedRepairTaskItemResponse(
        String id,
        String repairTaskNo,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        String faultType,
        String severity,
        String acceptedAt,
        String status) {

    public static AcceptedRepairTaskItemResponse from(AcceptedRepairTaskItem item) {
        return new AcceptedRepairTaskItemResponse(
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
