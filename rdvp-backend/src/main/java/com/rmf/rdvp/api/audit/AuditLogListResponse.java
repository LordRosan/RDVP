package com.rmf.rdvp.api.audit;

import java.util.List;

import com.rmf.rdvp.audit.AuditLogPage;

public record AuditLogListResponse(
        List<AuditLogResponse> items,
        long total) {

    public static AuditLogListResponse from(AuditLogPage page) {
        return new AuditLogListResponse(
                page.items().stream().map(AuditLogResponse::from).toList(),
                page.total());
    }
}
