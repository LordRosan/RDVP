package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.MyRepairTaskList;

public record MyRepairTaskListResponse(
        List<MyRepairTaskResponse> items,
        int total) {

    public static MyRepairTaskListResponse from(MyRepairTaskList result) {
        List<MyRepairTaskResponse> items = result.items()
                .stream()
                .map(MyRepairTaskResponse::from)
                .toList();
        return new MyRepairTaskListResponse(items, result.total());
    }
}
