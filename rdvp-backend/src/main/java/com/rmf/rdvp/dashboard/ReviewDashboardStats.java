package com.rmf.rdvp.dashboard;

public record ReviewDashboardStats(
        Long reviewedTotal,
        Long pendingArchiveReviews,
        Long pendingOperationsReviews) {
}
