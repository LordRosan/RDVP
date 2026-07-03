package com.rmf.rdvp.user;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryPasswordVerificationAttemptStore implements PasswordVerificationAttemptStore {

    private final ConcurrentMap<String, PasswordVerificationAttempt> attempts = new ConcurrentHashMap<>();

    @Override
    public Optional<PasswordVerificationAttempt> find(String userId) {
        return Optional.ofNullable(attempts.get(userId));
    }

    @Override
    public void clear(String userId) {
        attempts.remove(userId);
    }

    @Override
    public PasswordVerificationAttempt markVerified(String userId, Instant now, Duration verificationTtl) {
        PasswordVerificationAttempt attempt = new PasswordVerificationAttempt(
                userId,
                0,
                null,
                now.plus(verificationTtl),
                now);
        attempts.put(userId, attempt);
        return attempt;
    }

    @Override
    public PasswordVerificationAttempt registerFailure(
            String userId,
            Instant now,
            Duration lockDuration,
            int maxFailureCount) {
        return attempts.compute(userId, (key, current) -> {
            int failedCount = current == null ? 1 : current.failedCount() + 1;
            Instant lockedUntil = failedCount >= maxFailureCount ? now.plus(lockDuration) : null;
            return new PasswordVerificationAttempt(userId, failedCount, lockedUntil, null, now);
        });
    }
}
