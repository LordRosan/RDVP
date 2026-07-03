package com.rmf.rdvp.log;

import java.time.OffsetDateTime;

public record LogEntryCreate(
        String id,
        LogAction action,
        String targetId,
        String targetNo,
        String actorId,
        String actorName,
        LogEntryStatus status,
        String description,
        OffsetDateTime occurredAt) {
}
