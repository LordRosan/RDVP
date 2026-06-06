package com.rmf.rdvp.sync;

public record OfflineSyncStoredRecord(
        OfflineSyncRecordType recordType,
        String payloadHash,
        OfflineSyncRecordResult result) {
}
