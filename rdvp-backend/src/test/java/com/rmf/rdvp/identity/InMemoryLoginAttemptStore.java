package com.rmf.rdvp.identity;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryLoginAttemptStore implements LoginAttemptStore {

    private final ConcurrentMap<String, LoginAttempt> attempts = new ConcurrentHashMap<>();

    @Override
    public Optional<LoginAttempt> find(String username) {
        return Optional.ofNullable(attempts.get(username));
    }

    @Override
    public void clear(String username) {
        attempts.remove(username);
    }

    @Override
    public LoginAttempt registerFailure(
            String username,
            Instant now,
            Duration lockDuration,
            int maxFailureCount) {
        return attempts.compute(username, (key, current) -> {
            int failedCount = current == null ? 1 : current.failedCount() + 1;
            Instant lockedUntil = failedCount >= maxFailureCount ? now.plus(lockDuration) : null;
            return new LoginAttempt(username, failedCount, lockedUntil, now);
        });
    }
}
