package com.rmf.rdvp.home;

public record ArchiveDashboardStats(
        long deviceTotal,
        long archiveCreates,
        long archiveDeletes,
        long archiveUpdates,
        long archiveQueries,
        long archiveExports) {
}
