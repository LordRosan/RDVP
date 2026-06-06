package com.rmf.rdvp.audit;

public record AuditLogQuery(
        AuditAction action,
        String keyword,
        int page,
        int pageSize) {
}
