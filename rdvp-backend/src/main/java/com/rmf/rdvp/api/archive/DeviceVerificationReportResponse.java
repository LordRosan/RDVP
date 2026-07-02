package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceVerificationReport;

public record DeviceVerificationReportResponse(
        String id,
        String deviceId,
        String operatorId,
        String result,
        String description,
        String remark,
        String verifiedAt,
        String createdAt) {

    public static DeviceVerificationReportResponse from(DeviceVerificationReport report) {
        return new DeviceVerificationReportResponse(
                report.id(),
                report.deviceId(),
                report.operatorId(),
                report.result().name(),
                report.description(),
                report.remark(),
                toIsoString(report.verifiedAt()),
                toIsoString(report.createdAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        if (value == null) {
            return null;
        }

        return value.toInstant().toString();
    }
}
