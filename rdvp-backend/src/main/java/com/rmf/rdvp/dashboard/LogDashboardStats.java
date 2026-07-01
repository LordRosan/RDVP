package com.rmf.rdvp.dashboard;

public record LogDashboardStats(
        long logTotal,
        Long archiveOperationLogs,
        Long archiveReviewLogs,
        Long operationsOperationLogs,
        Long operationsReviewLogs) {
}
