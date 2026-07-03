package com.rmf.rdvp.log.api;

import java.util.List;

import com.rmf.rdvp.log.LogEntryPage;

public record LogEntryListResponse(
        List<LogEntryResponse> items,
        long total) {

    public static LogEntryListResponse from(LogEntryPage page) {
        return new LogEntryListResponse(
                page.items().stream().map(LogEntryResponse::from).toList(),
                page.total());
    }
}
