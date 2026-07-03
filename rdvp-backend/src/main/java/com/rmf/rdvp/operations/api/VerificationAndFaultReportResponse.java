package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.api.FaultReportResponse;
import com.rmf.rdvp.operations.VerificationAndFaultReportResult;

public record VerificationAndFaultReportResponse(
        DeviceVerificationReportResponse verificationReport,
        FaultReportResponse faultReport) {

    public static VerificationAndFaultReportResponse from(VerificationAndFaultReportResult result) {
        return new VerificationAndFaultReportResponse(
                DeviceVerificationReportResponse.from(result.verificationReport()),
                FaultReportResponse.from(result.faultReport()));
    }
}
