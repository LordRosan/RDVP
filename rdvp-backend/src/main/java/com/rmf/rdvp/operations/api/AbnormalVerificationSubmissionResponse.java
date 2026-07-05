package com.rmf.rdvp.operations.api;

import com.rmf.rdvp.operations.AbnormalVerificationSubmissionResult;

public record AbnormalVerificationSubmissionResponse(
        DeviceVerificationReportResponse verificationReport,
        FaultReportResponse faultReport) {

    public static AbnormalVerificationSubmissionResponse from(AbnormalVerificationSubmissionResult result) {
        return new AbnormalVerificationSubmissionResponse(
                DeviceVerificationReportResponse.from(result.verificationReport()),
                FaultReportResponse.from(result.faultReport()));
    }
}
