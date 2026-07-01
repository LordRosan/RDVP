package com.rmf.rdvp.operations;

import com.rmf.rdvp.archive.DeviceVerificationRecord;

public record DeviceVerificationAndFaultReportResult(
        DeviceVerificationRecord verificationRecord,
        FaultReportRecord faultReport) {
}
