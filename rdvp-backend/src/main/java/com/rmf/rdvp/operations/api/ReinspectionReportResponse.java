package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.ReinspectionReport;

public record ReinspectionReportResponse(
        String id,
        String reinspectionReportNo,
        String faultReportId,
        String result,
        String nextFaultStatus,
        String nextDeviceStatus,
        String createdAt) {

    public static ReinspectionReportResponse from(ReinspectionReport report) {
        return new ReinspectionReportResponse(
                report.id(),
                report.reinspectionReportNo(),
                report.faultReportId(),
                report.result().name(),
                report.nextFaultStatus().name(),
                report.nextDeviceStatus(),
                report.createdAt().toString());
    }
}
