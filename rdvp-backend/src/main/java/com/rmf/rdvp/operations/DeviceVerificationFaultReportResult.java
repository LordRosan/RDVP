package com.rmf.rdvp.operations;

import com.rmf.rdvp.archive.DeviceVerificationRecord;

public record DeviceVerificationFaultReportResult(
        DeviceVerificationRecord verificationRecord,
        FaultReportRecord faultReport) {
}
