package com.rmf.rdvp.log;

public interface LogQueryRepository {

    LogList queryArchiveLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset);

    LogList queryArchiveReviewLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset);

    LogList queryOperationsLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset);

    LogList queryOperationsReviewLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset);
}
