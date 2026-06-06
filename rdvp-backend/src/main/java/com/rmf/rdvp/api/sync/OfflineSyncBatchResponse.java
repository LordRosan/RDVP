package com.rmf.rdvp.api.sync;

import java.util.List;

import com.rmf.rdvp.sync.OfflineSyncBatchResult;

public record OfflineSyncBatchResponse(
        String clientBatchId,
        String status,
        List<OfflineSyncRecordResultResponse> results) {

    public static OfflineSyncBatchResponse from(OfflineSyncBatchResult result) {
        return new OfflineSyncBatchResponse(
                result.clientBatchId(),
                result.status().name(),
                result.results().stream().map(OfflineSyncRecordResultResponse::from).toList());
    }
}
