package com.rmf.rdvp.audit;

import java.util.List;

public record AuditLogPage(
        List<AuditLogRecord> items,
        long total) {
}
