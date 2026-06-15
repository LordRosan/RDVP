package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceArchiveChangeRequest;

public record DeviceArchiveChangeCreateResponse(
        String id,
        String status,
        String createdAt) {

    public static DeviceArchiveChangeCreateResponse from(DeviceArchiveChangeRequest request) {
        return new DeviceArchiveChangeCreateResponse(
                request.id(),
                request.status().name(),
                toIsoString(request.createdAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
