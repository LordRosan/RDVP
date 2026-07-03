package com.rmf.rdvp.user;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

public interface LoginAttemptStore {

    Optional<LoginAttempt> find(String username);

    void clear(String username);

    LoginAttempt registerFailure(
            String username,
            Instant now,
            Duration lockDuration,
            int maxFailureCount);
}
