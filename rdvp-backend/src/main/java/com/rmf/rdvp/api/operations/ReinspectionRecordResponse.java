package com.rmf.rdvp.api.operations;

import com.rmf.rdvp.operations.ReinspectionRecord;

public record ReinspectionRecordResponse(
        String id,
        String reinspectionRecordNo,
        String faultReportId,
        String result,
        String nextFaultStatus,
        String nextDeviceStatus,
        String createdAt) {

    public static ReinspectionRecordResponse from(ReinspectionRecord record) {
        return new ReinspectionRecordResponse(
                record.id(),
                record.reinspectionRecordNo(),
                record.faultReportId(),
                record.result().name(),
                record.nextFaultStatus().name(),
                record.nextDeviceStatus(),
                record.createdAt().toString());
    }
}
