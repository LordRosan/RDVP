package com.rmf.rdvp.operations;

import com.rmf.rdvp.archive.DeviceVerificationReport;

public record DeviceVerificationAndFaultReportResult(
        DeviceVerificationReport verificationReport,
        FaultReportRecord faultReport) {
}
