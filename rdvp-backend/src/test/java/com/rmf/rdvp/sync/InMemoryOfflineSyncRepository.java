package com.rmf.rdvp.sync;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryOfflineSyncRepository implements OfflineSyncRepository {

    private final List<StoredBatch> batches = new CopyOnWriteArrayList<>();
    private final List<StoredRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public Optional<OfflineSyncBatchResult> findBatchResult(String userId, String clientBatchId) {
        return batches.stream()
                .filter(batch -> batch.userId().equals(userId) && batch.clientBatchId().equals(clientBatchId))
                .findFirst()
                .map(batch -> new OfflineSyncBatchResult(
                        batch.clientBatchId(),
                        batch.status(),
                        records.stream()
                                .filter(record -> record.batchId().equals(batch.id()))
                                .sorted(Comparator.comparing(StoredRecord::createdAt))
                                .map(StoredRecord::result)
                                .toList()));
    }

    @Override
    public Optional<OfflineSyncStoredRecord> findRecord(String userId, String clientRecordId) {
        return records.stream()
                .filter(record -> record.userId().equals(userId) && record.result().clientRecordId().equals(clientRecordId))
                .sorted(Comparator.comparing(StoredRecord::createdAt).reversed())
                .map(record -> new OfflineSyncStoredRecord(record.recordType(), record.payloadHash(), record.result()))
                .findFirst();
    }

    @Override
    public void saveBatch(OfflineSyncBatchCreate batch) {
        batches.add(new StoredBatch(batch.id(), batch.clientBatchId(), batch.userId(), batch.status()));
        List<StoredRecord> nextRecords = new ArrayList<>();
        for (OfflineSyncRecordCreate record : batch.records()) {
            OfflineSyncRecordResult result = new OfflineSyncRecordResult(
                    record.clientRecordId(),
                    record.recordType(),
                    record.status(),
                    record.serverRecordId(),
                    record.errorCode(),
                    record.errorMessage());
            nextRecords.add(new StoredRecord(
                    batch.id(),
                    batch.userId(),
                    record.recordType(),
                    record.payloadHash(),
                    result,
                    record.createdAt()));
        }

        records.addAll(nextRecords);
    }

    private record StoredBatch(
            String id,
            String clientBatchId,
            String userId,
            OfflineSyncBatchStatus status) {
    }

    private record StoredRecord(
            String batchId,
            String userId,
            OfflineSyncRecordType recordType,
            String payloadHash,
            OfflineSyncRecordResult result,
            java.time.OffsetDateTime createdAt) {
    }
}
