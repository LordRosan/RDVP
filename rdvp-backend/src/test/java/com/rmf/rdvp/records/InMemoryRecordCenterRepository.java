package com.rmf.rdvp.records;

import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryRecordCenterRepository implements RecordCenterRepository {

    @Override
    public RecordListResponse queryArchiveRecords(String type, String keyword, int limit, int offset) {
        return empty();
    }

    @Override
    public RecordListResponse queryReviewRecords(String type, String keyword, int limit, int offset) {
        return empty();
    }

    @Override
    public RecordListResponse queryOperationsRecords(String type, String keyword, int limit, int offset) {
        return empty();
    }

    private RecordListResponse empty() {
        return new RecordListResponse(List.of(), 0);
    }
}
