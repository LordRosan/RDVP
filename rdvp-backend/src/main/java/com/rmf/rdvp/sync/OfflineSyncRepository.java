package com.rmf.rdvp.sync;

import java.util.Optional;

public interface OfflineSyncRepository {

    Optional<OfflineSyncBatchResult> findBatchResult(String userId, String clientBatchId);

    Optional<OfflineSyncStoredRecord> findRecord(String userId, String clientRecordId);

    void saveBatch(OfflineSyncBatchCreate batch);
}
