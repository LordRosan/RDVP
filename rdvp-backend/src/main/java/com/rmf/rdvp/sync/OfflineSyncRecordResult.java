package com.rmf.rdvp.sync;

public record OfflineSyncRecordResult(
        String clientRecordId,
        OfflineSyncRecordType recordType,
        OfflineSyncRecordStatus status,
        String serverRecordId,
        String errorCode,
        String errorMessage) {

    public static OfflineSyncRecordResult succeeded(
            String clientRecordId,
            OfflineSyncRecordType recordType,
            String serverRecordId) {
        return new OfflineSyncRecordResult(
                clientRecordId,
                recordType,
                OfflineSyncRecordStatus.SUCCEEDED,
                serverRecordId,
                null,
                null);
    }

    public static OfflineSyncRecordResult failed(
            String clientRecordId,
            OfflineSyncRecordType recordType,
            String errorCode,
            String errorMessage) {
        return new OfflineSyncRecordResult(
                clientRecordId,
                recordType,
                OfflineSyncRecordStatus.FAILED,
                null,
                errorCode,
                errorMessage);
    }

    public boolean success() {
        return status == OfflineSyncRecordStatus.SUCCEEDED;
    }
}
