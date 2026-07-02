package com.rmf.rdvp.api.archive;

import com.rmf.rdvp.api.operations.FaultReportResponse;
import com.rmf.rdvp.operations.DeviceVerificationAndFaultReportResult;

public record DeviceVerificationAndFaultReportResponse(
        DeviceVerificationReportResponse verificationReport,
        FaultReportResponse faultReport) {

    public static DeviceVerificationAndFaultReportResponse from(DeviceVerificationAndFaultReportResult result) {
        return new DeviceVerificationAndFaultReportResponse(
                DeviceVerificationReportResponse.from(result.verificationReport()),
                FaultReportResponse.from(result.faultReport()));
    }
}
