package com.rmf.rdvp.dashboard;

public record ArchiveDashboardStats(
        long deviceTotal,
        long archiveCreates,
        long archiveDeletes,
        long archiveUpdates,
        long archiveQueries) {
}
