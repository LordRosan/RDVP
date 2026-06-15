package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.RepairTaskPoolList;
import com.rmf.rdvp.operations.RepairerWorkloadSnapshot;

public record RepairTaskPoolListResponse(
        int radiusKm,
        RepairerWorkloadSnapshot workload,
        List<RepairTaskPoolItemResponse> items,
        int total) {

    public static RepairTaskPoolListResponse from(RepairTaskPoolList result) {
        List<RepairTaskPoolItemResponse> items = result.items()
                .stream()
                .map(RepairTaskPoolItemResponse::from)
                .toList();
        return new RepairTaskPoolListResponse(result.radiusKm(), result.workload(), items, result.total());
    }
}
