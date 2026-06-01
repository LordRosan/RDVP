package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.stream.Collectors;

import com.rmf.rdvp.archive.DeviceChangeRequest;

public record DeviceChangeReviewResponse(
        String id,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantName,
        String reason,
        String status,
        String createdAt,
        Map<String, DeviceChangeValueResponse> changes) {

    public static DeviceChangeReviewResponse from(DeviceChangeRequest request) {
        return new DeviceChangeReviewResponse(
                request.id(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantName(),
                request.reason(),
                request.status().name(),
                toIsoString(request.createdAt()),
                request.changes()
                        .entrySet()
                        .stream()
                        .collect(Collectors.toMap(
                                Map.Entry::getKey,
                                entry -> new DeviceChangeValueResponse(
                                        entry.getValue().oldValue(),
                                        entry.getValue().newValue()))));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }

    public record DeviceChangeValueResponse(
            String oldValue,
            String newValue) {
    }
}
