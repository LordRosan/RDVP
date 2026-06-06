package com.rmf.rdvp.sync;

import java.time.OffsetDateTime;
import java.util.List;

public record OfflineSyncBatchCreate(
        String id,
        String clientBatchId,
        String userId,
        OfflineSyncBatchStatus status,
        OffsetDateTime submittedAt,
        OffsetDateTime createdAt,
        List<OfflineSyncRecordCreate> records) {
}
