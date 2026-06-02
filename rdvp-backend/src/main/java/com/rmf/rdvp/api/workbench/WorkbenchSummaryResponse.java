package com.rmf.rdvp.api.workbench;

import com.rmf.rdvp.workbench.WorkbenchSummary;

public record WorkbenchSummaryResponse(
        long pendingChangeRequests,
        long availableRepairTasks,
        long activeRepairTasks,
        long pendingReinspections,
        long offlineDrafts) {

    public static WorkbenchSummaryResponse from(WorkbenchSummary summary) {
        return new WorkbenchSummaryResponse(
                summary.pendingChangeRequests(),
                summary.availableRepairTasks(),
                summary.activeRepairTasks(),
                summary.pendingReinspections(),
                summary.offlineDrafts());
    }
}
