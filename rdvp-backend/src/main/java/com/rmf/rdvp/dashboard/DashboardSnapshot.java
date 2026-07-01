package com.rmf.rdvp.dashboard;

public record DashboardSnapshot(
        ArchiveDashboardStats archive,
        OperationsDashboardStats operations,
        ReviewDashboardStats review,
        LogDashboardStats log) {
}
