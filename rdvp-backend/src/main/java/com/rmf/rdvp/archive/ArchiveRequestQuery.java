package com.rmf.rdvp.archive;

public record ArchiveRequestQuery(
        ArchiveRequestStatus status,
        String deviceCode,
        String applicantId,
        String type,
        int page,
        int pageSize) {
}
