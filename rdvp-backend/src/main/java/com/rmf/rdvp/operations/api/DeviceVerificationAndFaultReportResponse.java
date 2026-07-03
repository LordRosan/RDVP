package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.api.FaultReportResponse;
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
