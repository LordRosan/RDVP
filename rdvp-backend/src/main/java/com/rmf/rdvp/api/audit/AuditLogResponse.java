package com.rmf.rdvp.api.audit;

import java.time.OffsetDateTime;

import com.rmf.rdvp.audit.AuditLogRecord;

public record AuditLogResponse(
        String id,
        String action,
        String targetId,
        String targetNo,
        String actorId,
        String actorName,
        String status,
        String description,
        String occurredAt) {

    public static AuditLogResponse from(AuditLogRecord record) {
        return new AuditLogResponse(
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
