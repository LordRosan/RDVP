package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.AvailableRepairTaskList;
import com.rmf.rdvp.operations.RepairerWorkloadSnapshot;

public record AvailableRepairTaskListResponse(
        int radiusKm,
        RepairerWorkloadSnapshot workload,
        List<AvailableRepairTaskResponse> items,
        int total) {

    public static AvailableRepairTaskListResponse from(AvailableRepairTaskList result) {
        List<AvailableRepairTaskResponse> items = result.items()
                .stream()
                .map(AvailableRepairTaskResponse::from)
                .toList();
        return new AvailableRepairTaskListResponse(result.radiusKm(), result.workload(), items, result.total());
    }
}
