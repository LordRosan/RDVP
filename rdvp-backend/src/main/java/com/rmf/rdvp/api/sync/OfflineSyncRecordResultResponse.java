package com.rmf.rdvp.api.sync;

import com.rmf.rdvp.sync.OfflineSyncRecordResult;

public record OfflineSyncRecordResultResponse(
        String clientRecordId,
        String recordType,
        boolean success,
        String serverRecordId,
        String errorCode,
        String errorMessage) {

    public static OfflineSyncRecordResultResponse from(OfflineSyncRecordResult result) {
        return new OfflineSyncRecordResultResponse(
                result.clientRecordId(),
                result.recordType().name(),
                result.success(),
                result.serverRecordId(),
                result.errorCode(),
                result.errorMessage());
    }
}
