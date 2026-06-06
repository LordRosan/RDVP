package com.rmf.rdvp.sync;

import java.time.OffsetDateTime;

public record OfflineSyncRecordCreate(
        String id,
        String clientRecordId,
        OfflineSyncRecordType recordType,
        String payloadJson,
        String payloadHash,
        OfflineSyncRecordStatus status,
        String serverRecordId,
        String errorCode,
        String errorMessage,
        OffsetDateTime createdOfflineAt,
        OffsetDateTime processedAt,
        OffsetDateTime createdAt) {
}
