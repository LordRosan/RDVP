package com.rmf.rdvp.api.sync;

import java.util.List;

import com.rmf.rdvp.sync.OfflineSyncAuditPage;

public record OfflineSyncAuditListResponse(
        List<OfflineSyncAuditRecordResponse> items,
        long total) {

    public static OfflineSyncAuditListResponse from(OfflineSyncAuditPage page) {
        return new OfflineSyncAuditListResponse(
                page.items().stream().map(OfflineSyncAuditRecordResponse::from).toList(),
                page.total());
    }
}
