package com.rmf.rdvp.user;

import java.time.Instant;

public record PasswordVerificationAttempt(
        String userId,
        int failedCount,
        Instant lockedUntil,
        Instant verifiedUntil,
        Instant updatedAt) {
}
