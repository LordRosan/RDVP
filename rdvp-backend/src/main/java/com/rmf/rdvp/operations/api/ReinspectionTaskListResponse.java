package com.rmf.rdvp.operations.api;

import java.util.List;

import com.rmf.rdvp.operations.ReinspectionTaskList;

public record ReinspectionTaskListResponse(
        List<ReinspectionTaskResponse> items,
        int total) {

    public static ReinspectionTaskListResponse from(ReinspectionTaskList result) {
        List<ReinspectionTaskResponse> items = result.items()
                .stream()
                .map(ReinspectionTaskResponse::from)
                .toList();
        return new ReinspectionTaskListResponse(items, result.total());
    }
}
