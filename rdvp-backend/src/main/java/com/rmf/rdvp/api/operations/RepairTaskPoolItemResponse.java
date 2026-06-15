package com.rmf.rdvp.api.operations;

import java.math.BigDecimal;

import com.rmf.rdvp.operations.RepairTaskPoolItem;

public record RepairTaskPoolItemResponse(
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

    public static RepairTaskPoolItemResponse from(RepairTaskPoolItem item) {
        return new RepairTaskPoolItemResponse(
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

        public static DeviceLocationResponse from(RepairTaskPoolItem.DeviceLocation location) {
            return new DeviceLocationResponse(location.address(), location.longitude(), location.latitude());
        }
    }
}
