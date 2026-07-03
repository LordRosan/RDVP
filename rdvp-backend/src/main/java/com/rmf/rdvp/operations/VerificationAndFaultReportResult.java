package com.rmf.rdvp.operations;

import com.rmf.rdvp.operations.DeviceVerificationReport;

public record VerificationAndFaultReportResult(
        DeviceVerificationReport verificationReport,
        FaultReportRecord faultReport) {
}
