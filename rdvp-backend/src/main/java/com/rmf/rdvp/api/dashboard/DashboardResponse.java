package com.rmf.rdvp.api.dashboard;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.rmf.rdvp.dashboard.ArchiveDashboardStats;
import com.rmf.rdvp.dashboard.DashboardSnapshot;
import com.rmf.rdvp.dashboard.LogDashboardStats;
import com.rmf.rdvp.dashboard.OperationsDashboardStats;
import com.rmf.rdvp.dashboard.ReviewDashboardStats;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record DashboardResponse(
        ArchiveStatsResponse archive,
        OperationsStatsResponse operations,
        ReviewStatsResponse review,
        LogStatsResponse log) {

    public static DashboardResponse from(DashboardSnapshot snapshot) {
        return new DashboardResponse(
                ArchiveStatsResponse.from(snapshot.archive()),
                OperationsStatsResponse.from(snapshot.operations()),
                ReviewStatsResponse.from(snapshot.review()),
                LogStatsResponse.from(snapshot.log()));
    }

    public record ArchiveStatsResponse(
            long deviceTotal,
            long archiveCreates,
            long archiveDeletes,
            long archiveUpdates,
            long archiveQueries,
            long archiveExports) {

        public static ArchiveStatsResponse from(ArchiveDashboardStats stats) {
            if (stats == null) {
                return null;
            }

            return new ArchiveStatsResponse(
                    stats.deviceTotal(),
                    stats.archiveCreates(),
                    stats.archiveDeletes(),
                    stats.archiveUpdates(),
                    stats.archiveQueries(),
                    stats.archiveExports());
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
    public record ReviewStatsResponse(
            Long reviewedTotal,
            Long pendingArchiveReviews,
            Long pendingOperationsReviews) {

        public static ReviewStatsResponse from(ReviewDashboardStats stats) {
            if (stats == null) {
                return null;
            }

            return new ReviewStatsResponse(
                    stats.reviewedTotal(),
                    stats.pendingArchiveReviews(),
                    stats.pendingOperationsReviews());
        }
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record LogStatsResponse(
            long logTotal,
            Long archiveOperationLogs,
            Long archiveReviewLogs,
            Long operationsOperationLogs,
            Long operationsReviewLogs) {

        public static LogStatsResponse from(LogDashboardStats stats) {
            if (stats == null) {
                return null;
            }

            return new LogStatsResponse(
                    stats.logTotal(),
                    stats.archiveOperationLogs(),
                    stats.archiveReviewLogs(),
                    stats.operationsOperationLogs(),
                    stats.operationsReviewLogs());
        }
    }
}
