package com.rmf.rdvp.sync;

import java.util.List;

public record OfflineSyncAuditPage(
        List<OfflineSyncAuditRecord> items,
        long total) {
}
