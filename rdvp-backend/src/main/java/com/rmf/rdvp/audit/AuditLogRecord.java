package com.rmf.rdvp.audit;

import java.time.OffsetDateTime;

public record AuditLogRecord(
        String id,
        AuditAction action,
        String targetId,
        String targetNo,
        String actorId,
        String actorName,
        AuditStatus status,
        String description,
        OffsetDateTime occurredAt) {
}
