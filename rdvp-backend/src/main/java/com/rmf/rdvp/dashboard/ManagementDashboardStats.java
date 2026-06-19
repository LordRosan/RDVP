package com.rmf.rdvp.dashboard;

public record ManagementDashboardStats(
        Long reviewedTotal,
        Long pendingArchiveReviews,
        Long pendingOperationsReviews) {
}
