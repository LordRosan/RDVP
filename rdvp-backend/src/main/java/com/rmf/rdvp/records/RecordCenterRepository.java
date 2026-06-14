package com.rmf.rdvp.records;

public interface RecordCenterRepository {

    RecordListResponse queryArchiveRecords(String type, String keyword, int limit, int offset);

    RecordListResponse queryReviewRecords(String type, String keyword, int limit, int offset);

    RecordListResponse queryOperationsRecords(String type, String keyword, int limit, int offset);
}
