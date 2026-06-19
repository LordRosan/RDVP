package com.rmf.rdvp.dashboard;

public record OperationsDashboardStats(
        long taskPoolTotal,
        long verifications,
        long faultReports,
        long repairs,
        long reinspections) {
}
