package com.rmf.rdvp.home;

public record OperationsDashboardStats(
        long taskPoolTotal,
        long verifications,
        long faultReports,
        long repairs,
        long reinspections) {
}
