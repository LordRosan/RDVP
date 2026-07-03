package com.rmf.rdvp.log;

public record LogEntryQuery(
        LogAction action,
        String keyword,
        int page,
        int pageSize) {
}
