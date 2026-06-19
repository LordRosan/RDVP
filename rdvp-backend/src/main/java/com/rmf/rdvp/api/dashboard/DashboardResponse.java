package com.rmf.rdvp.api.dashboard;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.rmf.rdvp.dashboard.ArchiveDashboardStats;
import com.rmf.rdvp.dashboard.DashboardSnapshot;
import com.rmf.rdvp.dashboard.ManagementDashboardStats;
import com.rmf.rdvp.dashboard.OperationsDashboardStats;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record DashboardResponse(
        ArchiveStatsResponse archive,
        OperationsStatsResponse operations,
        ManagementStatsResponse management) {

    public static DashboardResponse from(DashboardSnapshot snapshot) {
        return new DashboardResponse(
                ArchiveStatsResponse.from(snapshot.archive()),
                OperationsStatsResponse.from(snapshot.operations()),
                ManagementStatsResponse.from(snapshot.management()));
    }

    public record ArchiveStatsResponse(
            long deviceTotal,
            long archiveCreates,
            long archiveDeletes,
            long archiveUpdates,
            long archiveQueries) {

        public static ArchiveStatsResponse from(ArchiveDashboardStats stats) {
            if (stats == null) {
                return null;
            }

            return new ArchiveStatsResponse(
                    stats.deviceTotal(),
                    stats.archiveCreates(),
                    stats.archiveDeletes(),
                    stats.archiveUpdates(),
                    stats.archiveQueries());
        }
    }

    public record OperationsStatsResponse(
            long taskPoolTotal,
            long verifications,
            long faultReports,
            long repairs,
            long reinspections) {

        public static OperationsStatsResponse from(OperationsDashboardStats stats) {
            if (stats == null) {
                return null;
            }

            return new OperationsStatsResponse(
                    stats.taskPoolTotal(),
                    stats.verifications(),
                    stats.faultReports(),
                    stats.repairs(),
                    stats.reinspections());
        }
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record ManagementStatsResponse(
            Long reviewedTotal,
            Long pendingArchiveReviews,
            Long pendingOperationsReviews) {

        public static ManagementStatsResponse from(ManagementDashboardStats stats) {
            if (stats == null) {
                return null;
            }

            return new ManagementStatsResponse(
                    stats.reviewedTotal(),
                    stats.pendingArchiveReviews(),
                    stats.pendingOperationsReviews());
        }
    }
}
