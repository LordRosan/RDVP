package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.stream.Collectors;

import com.rmf.rdvp.archive.DeviceArchiveRequest;

public record DeviceArchiveReviewResponse(
        String id,
        String type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String operatorId,
        String operatorName,
        String reason,
        String status,
        String initiatedAt,
        String createdAt,
        String submittedAt,
        Map<String, DeviceArchiveFieldChangeResponse> changes) {

    public static DeviceArchiveReviewResponse from(DeviceArchiveRequest request) {
        return new DeviceArchiveReviewResponse(
                request.id(),
                request.type().name(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                request.reason(),
                request.status().name(),
                toIsoString(request.initiatedAt()),
                toIsoString(request.createdAt()),
                toIsoString(request.createdAt()),
                request.changes()
                        .entrySet()
                        .stream()
                        .collect(Collectors.toMap(
                                Map.Entry::getKey,
                                entry -> new DeviceArchiveFieldChangeResponse(
                                        entry.getValue().oldValue(),
                                        entry.getValue().newValue()))));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }

    public record DeviceArchiveFieldChangeResponse(
            String oldValue,
            String newValue) {
    }
}
