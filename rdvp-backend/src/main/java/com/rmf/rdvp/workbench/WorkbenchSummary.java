package com.rmf.rdvp.workbench;

public record WorkbenchSummary(
        long pendingChangeRequests,
        long availableRepairTasks,
        long activeRepairTasks,
        long pendingReinspections,
        long offlineDrafts) {
}
