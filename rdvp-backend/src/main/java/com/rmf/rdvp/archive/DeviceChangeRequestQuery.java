package com.rmf.rdvp.archive;

public record DeviceChangeRequestQuery(
        DeviceChangeRequestStatus status,
        String deviceCode,
        String applicantId,
        int page,
        int pageSize) {
}
