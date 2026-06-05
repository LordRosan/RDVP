package com.rmf.rdvp.audit;

public record AuditLogQuery(
        AuditAction action,
        int page,
        int pageSize) {
}
