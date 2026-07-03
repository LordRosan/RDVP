package com.rmf.rdvp.home;

public record LogDashboardStats(
        long logTotal,
        Long archiveOperationLogs,
        Long archiveReviewLogs,
        Long operationsOperationLogs,
        Long operationsReviewLogs) {
}
