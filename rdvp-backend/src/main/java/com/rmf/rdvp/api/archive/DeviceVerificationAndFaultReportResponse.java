package com.rmf.rdvp.api.archive;

import com.rmf.rdvp.api.operations.FaultReportResponse;
import com.rmf.rdvp.operations.DeviceVerificationAndFaultReportResult;

public record DeviceVerificationAndFaultReportResponse(
        DeviceVerificationRecordResponse verificationRecord,
        FaultReportResponse faultReport) {

    public static DeviceVerificationAndFaultReportResponse from(DeviceVerificationAndFaultReportResult result) {
        return new DeviceVerificationAndFaultReportResponse(
                DeviceVerificationRecordResponse.from(result.verificationRecord()),
                FaultReportResponse.from(result.faultReport()));
    }
}
