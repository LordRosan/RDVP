package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.stream.Collectors;

import com.rmf.rdvp.archive.DeviceArchiveChangeRequest;

public record DeviceArchiveReviewResponse(
        String id,
        String type,
        String deviceId,
        String deviceCode,
        String deviceName,
        String applicantName,
        String reason,
        String status,
        String initiatedAt,
        String createdAt,
        String submittedAt,
        Map<String, DeviceArchiveChangeValueResponse> changes) {

    public static DeviceArchiveReviewResponse from(DeviceArchiveChangeRequest request) {
        return new DeviceArchiveReviewResponse(
                request.id(),
                request.type().name(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
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
                                entry -> new DeviceArchiveChangeValueResponse(
                                        entry.getValue().oldValue(),
                                        entry.getValue().newValue()))));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }

    public record DeviceArchiveChangeValueResponse(
            String oldValue,
            String newValue) {
    }
}
