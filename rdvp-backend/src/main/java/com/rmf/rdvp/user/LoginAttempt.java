package com.rmf.rdvp.user;

import java.time.Instant;

public record LoginAttempt(
        String username,
        int failedCount,
        Instant lockedUntil,
        Instant updatedAt) {
}
