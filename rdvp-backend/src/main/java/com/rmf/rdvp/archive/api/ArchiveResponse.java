package com.rmf.rdvp.archive.api;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import com.rmf.rdvp.archive.Archive;

public record ArchiveResponse(
        String id,
        String deviceCode,
        String name,
        String model,
        String manufacturer,
        LocationResponse location,
        String status,
        String lastVerificationTime,
        ArchiveRequestStateResponse archiveRequestState,
        List<Object> recentFaultReports,
        List<Object> recentRepairReports,
        List<Object> recentVerificationReports) {

    public static ArchiveResponse from(Archive archive) {
        return new ArchiveResponse(
                archive.id(),
                archive.deviceCode(),
                archive.name(),
                archive.model(),
                archive.manufacturer(),
                new LocationResponse(archive.address(), archive.longitude(), archive.latitude()),
                archive.status(),
                toIsoString(archive.lastVerificationTime()),
                ArchiveRequestStateResponse.from(archive.archiveRequestState()),
                List.of(),
                List.of(),
                List.of());
    }

    private static String toIsoString(OffsetDateTime value) {
        if (value == null) {
            return null;
        }

        return value.toInstant().toString();
    }

    public record LocationResponse(
            String address,
            BigDecimal longitude,
            BigDecimal latitude) {
    }

    public record ArchiveRequestStateResponse(
            boolean locked,
            String pendingRequestId,
            String freezeUntil) {

        static ArchiveRequestStateResponse from(Archive.ArchiveRequestState archiveRequestState) {
            return new ArchiveRequestStateResponse(
                    archiveRequestState.locked(),
                    archiveRequestState.pendingRequestId(),
                    toIsoString(archiveRequestState.freezeUntil()));
        }
    }
}
