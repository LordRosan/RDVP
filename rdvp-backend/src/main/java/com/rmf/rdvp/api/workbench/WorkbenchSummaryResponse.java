package com.rmf.rdvp.api.workbench;

import com.rmf.rdvp.workbench.WorkbenchSummary;

public record WorkbenchSummaryResponse(
        long pendingDeviceArchiveChangeRequests,
        long repairTaskPoolItems,
        long acceptedRepairTasks,
        long pendingReinspections) {

    public static WorkbenchSummaryResponse from(WorkbenchSummary summary) {
        return new WorkbenchSummaryResponse(
                summary.pendingDeviceArchiveChangeRequests(),
                summary.repairTaskPoolItems(),
                summary.acceptedRepairTasks(),
                summary.pendingReinspections());
    }
}
