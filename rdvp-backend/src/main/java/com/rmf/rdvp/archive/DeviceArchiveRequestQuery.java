package com.rmf.rdvp.archive;

public record DeviceArchiveRequestQuery(
        DeviceArchiveRequestStatus status,
        String deviceCode,
        String applicantId,
        String type,
        int page,
        int pageSize) {
}
