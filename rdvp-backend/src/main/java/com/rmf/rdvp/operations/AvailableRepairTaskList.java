package com.rmf.rdvp.operations;

import java.util.List;

public record AvailableRepairTaskList(
        int radiusKm,
        RepairerWorkloadSnapshot workload,
        List<AvailableRepairTaskSummary> items,
        int total) {
}
