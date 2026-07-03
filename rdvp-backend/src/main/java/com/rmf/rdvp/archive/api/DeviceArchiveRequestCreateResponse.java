package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceArchiveRequest;

public record DeviceArchiveRequestCreateResponse(
        String id,
        String status,
        String createdAt) {

    public static DeviceArchiveRequestCreateResponse from(DeviceArchiveRequest request) {
        return new DeviceArchiveRequestCreateResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.createdAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
