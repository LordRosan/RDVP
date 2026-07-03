package com.rmf.rdvp.log.api;

import java.time.OffsetDateTime;

import com.rmf.rdvp.log.LogEntry;

public record LogEntryResponse(
        String id,
        String action,
        String targetId,
        String targetNo,
        String actorId,
        String actorName,
        String status,
        String description,
        String occurredAt) {

    public static LogEntryResponse from(LogEntry record) {
        return new LogEntryResponse(
                record.id(),
                record.action().name(),
                record.targetId(),
                record.targetNo(),
                record.actorId(),
                record.actorName(),
                record.status().name(),
                record.description(),
                toIsoString(record.occurredAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
