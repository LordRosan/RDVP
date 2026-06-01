package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceChangeRequest;

public record DeviceChangeCreateResponse(
        String id,
        String status,
        String createdAt) {

    public static DeviceChangeCreateResponse from(DeviceChangeRequest request) {
        return new DeviceChangeCreateResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.createdAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
