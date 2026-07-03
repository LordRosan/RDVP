package com.rmf.rdvp.operations;

import com.rmf.rdvp.operations.DeviceVerificationReport;

public record DeviceVerificationAndFaultReportResult(
        DeviceVerificationReport verificationReport,
        FaultReportRecord faultReport) {
}
