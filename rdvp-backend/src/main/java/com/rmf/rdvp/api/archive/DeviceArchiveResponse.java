package com.rmf.rdvp.api.archive;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import com.rmf.rdvp.archive.DeviceArchive;

public record DeviceArchiveResponse(
        String id,
        String deviceCode,
        String name,
        String model,
        String manufacturer,
        LocationResponse location,
        String status,
        String lastVerificationTime,
        ChangeStateResponse changeState,
        List<Object> recentFaultReports,
        List<Object> recentRepairReports,
        List<Object> recentVerificationRecords) {

    public static DeviceArchiveResponse from(DeviceArchive archive) {
        return new DeviceArchiveResponse(
                archive.id(),
                archive.deviceCode(),
                archive.name(),
                archive.model(),
                archive.manufacturer(),
                new LocationResponse(archive.address(), archive.longitude(), archive.latitude()),
                archive.status(),
                toIsoString(archive.lastVerificationTime()),
                ChangeStateResponse.from(archive.changeState()),
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

    public record ChangeStateResponse(
            boolean locked,
            String pendingRequestId,
            String freezeUntil) {

        static ChangeStateResponse from(DeviceArchive.ChangeState changeState) {
            return new ChangeStateResponse(
                    changeState.locked(),
                    changeState.pendingRequestId(),
                    toIsoString(changeState.freezeUntil()));
        }
    }
}
