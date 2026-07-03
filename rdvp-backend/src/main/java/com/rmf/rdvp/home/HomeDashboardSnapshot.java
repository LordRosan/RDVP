package com.rmf.rdvp.home;

public record HomeDashboardSnapshot(
        ArchiveDashboardStats archive,
        OperationsDashboardStats operations,
        ReviewDashboardStats review,
        LogDashboardStats log) {
}
