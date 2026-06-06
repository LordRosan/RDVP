package com.rmf.rdvp.api.sync;

import java.time.OffsetDateTime;

import com.rmf.rdvp.sync.OfflineSyncAuditRecord;

public record OfflineSyncAuditRecordResponse(
        String batchId,
        String clientBatchId,
        String batchStatus,
        String userId,
        String operatorName,
        String clientRecordId,
        String recordType,
        String status,
        String serverRecordId,
        String errorCode,
        String errorMessage,
        String createdOfflineAt,
        String submittedAt,
        String processedAt) {

    public static OfflineSyncAuditRecordResponse from(OfflineSyncAuditRecord record) {
        return new OfflineSyncAuditRecordResponse(
                record.batchId(),
                record.clientBatchId(),
                record.batchStatus().name(),
                record.userId(),
                record.operatorName(),
                record.clientRecordId(),
                record.recordType().name(),
                record.status().name(),
                record.serverRecordId(),
                record.errorCode(),
                record.errorMessage(),
                toIsoString(record.createdOfflineAt()),
                toIsoString(record.submittedAt()),
                toIsoString(record.processedAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        return value == null ? null : value.toInstant().toString();
    }
}
