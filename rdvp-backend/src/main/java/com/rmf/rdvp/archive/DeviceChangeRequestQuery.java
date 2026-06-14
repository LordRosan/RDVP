package com.rmf.rdvp.archive;

public record DeviceChangeRequestQuery(
        DeviceChangeRequestStatus status,
        String deviceCode,
        String applicantId,
        String type,
        int page,
        int pageSize) {
}
