package com.rmf.rdvp.archive;

public record DeviceArchiveChangeRequestQuery(
        DeviceArchiveChangeRequestStatus status,
        String deviceCode,
        String applicantId,
        String type,
        int page,
        int pageSize) {
}
