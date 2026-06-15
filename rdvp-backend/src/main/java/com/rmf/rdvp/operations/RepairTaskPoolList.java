package com.rmf.rdvp.operations;

import java.util.List;

public record RepairTaskPoolList(
        int radiusKm,
        RepairerWorkloadSnapshot workload,
        List<RepairTaskPoolItem> items,
        int total) {
}
