package com.rmf.rdvp.operations;

import java.util.List;

public record AcceptedRepairTaskList(
        List<AcceptedRepairTaskItem> items,
        int total) {
}
