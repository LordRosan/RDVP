package com.rmf.rdvp.operations;

import java.util.List;

public record MyRepairTaskList(
        List<MyRepairTaskSummary> items,
        int total) {
}
