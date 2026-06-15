package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.TaskAcceptanceList;
import com.rmf.rdvp.operations.RepairerWorkloadSnapshot;

public record TaskAcceptanceListResponse(
        int radiusKm,
        RepairerWorkloadSnapshot workload,
        List<TaskAcceptanceItemResponse> items,
        int total) {

    public static TaskAcceptanceListResponse from(TaskAcceptanceList result) {
        List<TaskAcceptanceItemResponse> items = result.items()
                .stream()
                .map(TaskAcceptanceItemResponse::from)
                .toList();
        return new TaskAcceptanceListResponse(result.radiusKm(), result.workload(), items, result.total());
    }
}
