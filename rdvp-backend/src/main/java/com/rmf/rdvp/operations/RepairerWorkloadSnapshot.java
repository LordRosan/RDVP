package com.rmf.rdvp.operations;

public record RepairerWorkloadSnapshot(
        RepairerWorkloadStatus status,
        int activeTaskCount,
        int maxActiveTaskCount,
        int maxRadiusKm,
        int recommendedRadiusKm,
        String message,
        boolean canAccept) {
}
