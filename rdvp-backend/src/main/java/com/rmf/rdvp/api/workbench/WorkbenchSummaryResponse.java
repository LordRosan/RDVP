package com.rmf.rdvp.api.workbench;

import com.rmf.rdvp.workbench.WorkbenchSummary;

public record WorkbenchSummaryResponse(
        long pendingDeviceArchiveRequests,
        long taskAcceptanceItems,
        long repairTasks,
        long pendingReinspections) {

    public static WorkbenchSummaryResponse from(WorkbenchSummary summary) {
        return new WorkbenchSummaryResponse(
                summary.pendingDeviceArchiveRequests(),
                summary.taskAcceptanceItems(),
                summary.repairTasks(),
                summary.pendingReinspections());
    }
}
