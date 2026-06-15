package com.rmf.rdvp.workbench;

public record WorkbenchSummary(
        long pendingDeviceArchiveChangeRequests,
        long repairTaskPoolItems,
        long acceptedRepairTasks,
        long pendingReinspections) {
}
