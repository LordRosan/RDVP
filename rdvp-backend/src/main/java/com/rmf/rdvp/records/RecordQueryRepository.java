package com.rmf.rdvp.records;

public interface RecordQueryRepository {

    RecordListResponse queryArchiveRecords(String type, String keyword, int limit, int offset);

    RecordListResponse queryReviewRecords(String type, String keyword, int limit, int offset);

    RecordListResponse queryOperationRecords(String type, String keyword, int limit, int offset);
}
