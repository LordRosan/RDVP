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
public class JdbcLoginAttemptStore implements LoginAttemptStore {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcLoginAttemptStore(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<LoginAttempt> find(String username) {
        var attempts = jdbcTemplate.query(
                """
                        SELECT username, failed_count, locked_until, updated_at
                        FROM user_login_attempts
                        WHERE username = :username
                        """,
                Map.of("username", username),
                (resultSet, rowNumber) -> new LoginAttempt(
                        resultSet.getString("username"),
                        resultSet.getInt("failed_count"),
                        resultSet.getObject("locked_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("locked_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("updated_at", OffsetDateTime.class).toInstant()));
        return attempts.stream().findFirst();
    }

    @Override
    public void clear(String username) {
        jdbcTemplate.update(
                "DELETE FROM user_login_attempts WHERE username = :username",
                Map.of("username", username));
    }

    @Override
    public LoginAttempt registerFailure(
            String username,
            Instant now,
            Duration lockDuration,
            int maxFailureCount) {
        OffsetDateTime updatedAt = OffsetDateTime.ofInstant(now, ZoneOffset.UTC);
        OffsetDateTime lockUntil = OffsetDateTime.ofInstant(now.plus(lockDuration), ZoneOffset.UTC);
        return jdbcTemplate.queryForObject(
                """
                        INSERT INTO user_login_attempts (
                            username,
                            failed_count,
                            locked_until,
                            updated_at
                        ) VALUES (
                            :username,
                            1,
                            CASE WHEN :maxFailureCount <= 1 THEN :lockUntil ELSE NULL END,
                            :updatedAt
                        )
                        ON CONFLICT (username) DO UPDATE SET
                            failed_count = user_login_attempts.failed_count + 1,
                            locked_until = CASE
                                WHEN user_login_attempts.failed_count + 1 >= :maxFailureCount
                                THEN :lockUntil
                                ELSE NULL
                            END,
                            updated_at = :updatedAt
                        RETURNING username, failed_count, locked_until, updated_at
                        """,
                new MapSqlParameterSource()
                        .addValue("username", username)
                        .addValue("maxFailureCount", maxFailureCount)
                        .addValue("lockUntil", lockUntil)
                        .addValue("updatedAt", updatedAt),
                (resultSet, rowNumber) -> new LoginAttempt(
                        resultSet.getString("username"),
                        resultSet.getInt("failed_count"),
                        resultSet.getObject("locked_until", OffsetDateTime.class) == null
                                ? null
                                : resultSet.getObject("locked_until", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("updated_at", OffsetDateTime.class).toInstant()));
    }
}
