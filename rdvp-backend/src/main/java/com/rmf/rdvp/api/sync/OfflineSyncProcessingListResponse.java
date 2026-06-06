package com.rmf.rdvp.api.sync;

import java.util.List;

import com.rmf.rdvp.sync.OfflineSyncProcessingPage;

public record OfflineSyncProcessingListResponse(
        List<OfflineSyncProcessingRecordResponse> items,
        long total) {

    public static OfflineSyncProcessingListResponse from(OfflineSyncProcessingPage page) {
        return new OfflineSyncProcessingListResponse(
                page.items().stream().map(OfflineSyncProcessingRecordResponse::from).toList(),
                page.total());
    }
}
