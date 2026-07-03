package com.rmf.rdvp.user;

import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcPasswordVerificationAttemptStore implements PasswordVerificationAttemptStore {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcPasswordVerificationAttemptStore(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<PasswordVerificationAttempt> find(String userId) {
        var attempts = jdbcTemplate.query(
                """
                        SELECT user_id, failed_count, locked_until, verified_until, updated_at
                        FROM user_password_verification_attempts
                        WHERE user_id = :userId
                        """,
                Map.of("userId", userId),
                (resultSet, rowNumber) -> new PasswordVerificationAttempt(
                        resultSet.getString("user_id"),
                        resultSet.getInt("failed_count"),
                        resultSet.getObject("locked_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("locked_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("verified_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("verified_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("updated_at", OffsetDateTime.class).toInstant()));
        return attempts.stream().findFirst();
    }

    @Override
    public void clear(String userId) {
        jdbcTemplate.update(
                "DELETE FROM user_password_verification_attempts WHERE user_id = :userId",
                Map.of("userId", userId));
    }

    @Override
    public PasswordVerificationAttempt markVerified(String userId, Instant now, Duration verificationTtl) {
        OffsetDateTime updatedAt = OffsetDateTime.ofInstant(now, ZoneOffset.UTC);
        OffsetDateTime verifiedUntil = OffsetDateTime.ofInstant(now.plus(verificationTtl), ZoneOffset.UTC);
        return jdbcTemplate.queryForObject(
                """
                        INSERT INTO user_password_verification_attempts (
                            user_id,
                            failed_count,
                            locked_until,
                            verified_until,
                            updated_at
                        ) VALUES (
                            :userId,
                            0,
                            NULL,
                            :verifiedUntil,
                            :updatedAt
                        )
                        ON CONFLICT (user_id) DO UPDATE SET
                            failed_count = 0,
                            locked_until = NULL,
                            verified_until = :verifiedUntil,
                            updated_at = :updatedAt
                        RETURNING user_id, failed_count, locked_until, verified_until, updated_at
                        """,
                new MapSqlParameterSource()
                        .addValue("userId", userId)
                        .addValue("verifiedUntil", verifiedUntil)
                        .addValue("updatedAt", updatedAt),
                (resultSet, rowNumber) -> new PasswordVerificationAttempt(
                        resultSet.getString("user_id"),
                        resultSet.getInt("failed_count"),
                        resultSet.getObject("locked_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("locked_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("verified_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("verified_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("updated_at", OffsetDateTime.class).toInstant()));
    }

    @Override
    public PasswordVerificationAttempt registerFailure(
            String userId,
            Instant now,
            Duration lockDuration,
            int maxFailureCount) {
        OffsetDateTime updatedAt = OffsetDateTime.ofInstant(now, ZoneOffset.UTC);
        OffsetDateTime lockUntil = OffsetDateTime.ofInstant(now.plus(lockDuration), ZoneOffset.UTC);
        return jdbcTemplate.queryForObject(
                """
                        INSERT INTO user_password_verification_attempts (
                            user_id,
                            failed_count,
                            locked_until,
                            verified_until,
                            updated_at
                        ) VALUES (
                            :userId,
                            1,
                            CASE WHEN :maxFailureCount <= 1 THEN :lockUntil ELSE NULL END,
                            NULL,
                            :updatedAt
                        )
                        ON CONFLICT (user_id) DO UPDATE SET
                            failed_count = user_password_verification_attempts.failed_count + 1,
                            locked_until = CASE
                                WHEN user_password_verification_attempts.failed_count + 1 >= :maxFailureCount
                                THEN :lockUntil
                                ELSE NULL
                            END,
                            verified_until = NULL,
                            updated_at = :updatedAt
                        RETURNING user_id, failed_count, locked_until, verified_until, updated_at
                        """,
                new MapSqlParameterSource()
                        .addValue("userId", userId)
                        .addValue("maxFailureCount", maxFailureCount)
                        .addValue("lockUntil", lockUntil)
                        .addValue("updatedAt", updatedAt),
                (resultSet, rowNumber) -> new PasswordVerificationAttempt(
                        resultSet.getString("user_id"),
                        resultSet.getInt("failed_count"),
                        resultSet.getObject("locked_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("locked_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("verified_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("verified_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("updated_at", OffsetDateTime.class).toInstant()));
    }
}
