package com.rmf.rdvp.operations;

import java.util.List;

public record ReinspectionTaskList(
        List<ReinspectionTaskSummary> items,
        int total) {
}
