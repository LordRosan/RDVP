package com.rmf.rdvp.identity;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

public interface PasswordVerificationAttemptStore {

    Optional<PasswordVerificationAttempt> find(String userId);

    void clear(String userId);

    PasswordVerificationAttempt registerFailure(
            String userId,
            Instant now,
            Duration lockDuration,
            int maxFailureCount);
}
