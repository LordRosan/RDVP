package com.rmf.rdvp.workbench;

public record WorkbenchSummary(
        long pendingDeviceArchiveRequests,
        long taskAcceptanceItems,
        long repairTasks,
        long pendingReinspections) {
}
