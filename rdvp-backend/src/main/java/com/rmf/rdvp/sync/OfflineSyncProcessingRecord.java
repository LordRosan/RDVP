package com.rmf.rdvp.sync;

import java.time.OffsetDateTime;

public record OfflineSyncProcessingRecord(
        String batchId,
        String clientBatchId,
        OfflineSyncBatchStatus batchStatus,
        String userId,
        String operatorName,
        String clientRecordId,
        OfflineSyncRecordType recordType,
        OfflineSyncRecordStatus status,
        String serverRecordId,
        String errorCode,
        String errorMessage,
        OffsetDateTime createdOfflineAt,
        OffsetDateTime submittedAt,
        OffsetDateTime processedAt) {
}
