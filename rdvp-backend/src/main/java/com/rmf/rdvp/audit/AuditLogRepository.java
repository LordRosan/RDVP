package com.rmf.rdvp.audit;

public interface AuditLogRepository {

    void append(AuditLogCreate create);

    AuditLogPage list(AuditLogQuery query);

    long countSuccessByAction(AuditAction action);
}
