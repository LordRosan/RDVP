package com.rmf.rdvp.api.archive;

import com.rmf.rdvp.api.operations.FaultReportResponse;
import com.rmf.rdvp.operations.DeviceVerificationFaultReportResult;

public record DeviceVerificationFaultReportResponse(
        DeviceVerificationRecordResponse verificationRecord,
        FaultReportResponse faultReport) {

    public static DeviceVerificationFaultReportResponse from(DeviceVerificationFaultReportResult result) {
        return new DeviceVerificationFaultReportResponse(
                DeviceVerificationRecordResponse.from(result.verificationRecord()),
                FaultReportResponse.from(result.faultReport()));
    }
}
