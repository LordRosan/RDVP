package com.rmf.rdvp.log;

import java.util.List;

public record LogList(
        List<LogItem> items,
        long total) {
}
