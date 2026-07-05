package com.rmf.rdvp.operations;

public record AbnormalVerificationSubmissionResult(
        DeviceVerificationReport verificationReport,
        FaultReportRecord faultReport) {
}
