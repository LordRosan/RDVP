package com.rmf.rdvp.operations;

import java.util.List;

public record TaskAcceptanceList(
        int radiusKm,
        RepairerWorkloadSnapshot workload,
        List<TaskAcceptanceItem> items,
        int total) {
}
