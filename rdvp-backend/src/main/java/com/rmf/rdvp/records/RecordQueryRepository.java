package com.rmf.rdvp.records;

public interface RecordQueryRepository {

    RecordListResponse queryArchiveRecords(
            String type,
            String keyword,
            RecordQueryTimeRange timeRange,
            int limit,
            int offset);

    RecordListResponse queryReviewRecords(
            String type,
            String keyword,
            RecordQueryTimeRange timeRange,
            int limit,
            int offset);

    RecordListResponse queryOperationsRecords(
            String type,
            String keyword,
            RecordQueryTimeRange timeRange,
            int limit,
            int offset);
}
