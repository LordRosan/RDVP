package com.rmf.rdvp.sync;

import java.util.List;

public record OfflineSyncBatchResult(
        String clientBatchId,
        OfflineSyncBatchStatus status,
        List<OfflineSyncRecordResult> results) {
}
