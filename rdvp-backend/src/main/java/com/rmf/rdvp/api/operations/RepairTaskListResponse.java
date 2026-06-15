package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.RepairTaskList;

public record RepairTaskListResponse(
        List<RepairTaskItemResponse> items,
        int total) {

    public static RepairTaskListResponse from(RepairTaskList result) {
        List<RepairTaskItemResponse> items = result.items()
                .stream()
                .map(RepairTaskItemResponse::from)
                .toList();
        return new RepairTaskListResponse(items, result.total());
    }
}
