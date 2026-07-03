package com.rmf.rdvp.log;

import java.util.List;

public record LogEntryPage(
        List<LogEntry> items,
        long total) {
}
