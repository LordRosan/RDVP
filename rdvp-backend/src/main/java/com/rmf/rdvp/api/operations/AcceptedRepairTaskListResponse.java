package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.AcceptedRepairTaskList;

public record AcceptedRepairTaskListResponse(
        List<AcceptedRepairTaskItemResponse> items,
        int total) {

    public static AcceptedRepairTaskListResponse from(AcceptedRepairTaskList result) {
        List<AcceptedRepairTaskItemResponse> items = result.items()
                .stream()
                .map(AcceptedRepairTaskItemResponse::from)
                .toList();
        return new AcceptedRepairTaskListResponse(items, result.total());
    }
}
