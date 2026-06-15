package com.rmf.rdvp.api.operations;

import com.rmf.rdvp.operations.ReinspectionTaskSummary;

public record ReinspectionTaskResponse(
        String id,
        String faultReportId,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        String severity,
        RepairTaskPoolItemResponse.DeviceLocationResponse location,
        String repairedAt,
        String status) {

    public static ReinspectionTaskResponse from(ReinspectionTaskSummary item) {
        return new ReinspectionTaskResponse(
                item.id(),
                item.faultReportId(),
                item.faultReportNo(),
                item.deviceCode(),
                item.deviceName(),
                item.severity().name(),
                RepairTaskPoolItemResponse.DeviceLocationResponse.from(item.location()),
                item.repairedAt() == null ? null : item.repairedAt().toString(),
                item.status().name());
    }
}
