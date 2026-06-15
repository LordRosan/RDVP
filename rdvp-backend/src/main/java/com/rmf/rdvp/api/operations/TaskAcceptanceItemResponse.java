package com.rmf.rdvp.api.operations;

import java.math.BigDecimal;

import com.rmf.rdvp.operations.TaskAcceptanceItem;

public record TaskAcceptanceItemResponse(
        String id,
        String faultReportId,
        String faultReportNo,
        String deviceCode,
        String deviceName,
        String faultType,
        String severity,
        BigDecimal distanceKm,
        DeviceLocationResponse location,
        String submittedAt,
        String status,
        String taskType) {

    public static TaskAcceptanceItemResponse from(TaskAcceptanceItem item) {
        return new TaskAcceptanceItemResponse(
                item.id(),
                item.faultReportId(),
                item.faultReportNo(),
                item.deviceCode(),
                item.deviceName(),
                item.faultType().name(),
                item.severity().name(),
                item.distanceKm(),
                DeviceLocationResponse.from(item.location()),
                item.submittedAt().toString(),
                item.status().name(),
                item.taskType());
    }

    public record DeviceLocationResponse(
            String address,
            BigDecimal longitude,
            BigDecimal latitude) {

        public static DeviceLocationResponse from(TaskAcceptanceItem.DeviceLocation location) {
            return new DeviceLocationResponse(location.address(), location.longitude(), location.latitude());
        }
    }
}
