package com.rmf.rdvp.archive.api;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import com.rmf.rdvp.archive.Archive;
import com.rmf.rdvp.archive.ArchiveImage;

public record ArchiveResponse(
        String id,
        String deviceCode,
        String name,
        String deviceType,
        String model,
        String manufacturer,
        String commissionedAt,
        String managementDepartment,
        LocationResponse location,
        String status,
        String lastVerificationTime,
        ArchiveRequestStateResponse archiveRequestState,
        List<ArchiveImageSummaryResponse> images,
        List<Object> recentFaultReports,
        List<Object> recentRepairReports,
        List<Object> recentVerificationReports) {

    public static ArchiveResponse from(Archive archive) {
        return from(archive, List.of());
    }

    public static ArchiveResponse from(Archive archive, List<ArchiveImage> images) {
        return new ArchiveResponse(
                archive.id(),
                archive.deviceCode(),
                archive.name(),
                archive.deviceType(),
                archive.model(),
                archive.manufacturer(),
                toDateString(archive.commissionedAt()),
                archive.managementDepartment(),
                new LocationResponse(archive.address(), archive.longitude(), archive.latitude()),
                archive.status(),
                toIsoString(archive.lastVerificationTime()),
                ArchiveRequestStateResponse.from(archive.archiveRequestState()),
                images.stream().map(ArchiveImageSummaryResponse::from).toList(),
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

    private static String toDateString(LocalDate value) {
        if (value == null) {
            return null;
        }

        return value.toString();
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
