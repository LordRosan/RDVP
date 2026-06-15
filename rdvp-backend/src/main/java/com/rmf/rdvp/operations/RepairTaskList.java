package com.rmf.rdvp.operations;

import java.util.List;

public record RepairTaskList(
        List<RepairTaskItem> items,
        int total) {
}
