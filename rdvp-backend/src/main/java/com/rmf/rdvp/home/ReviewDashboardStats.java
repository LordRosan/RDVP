package com.rmf.rdvp.home;

public record ReviewDashboardStats(
        Long reviewedTotal,
        Long pendingArchiveReviews,
        Long pendingOperationsReviews) {
}
