package com.rmf.rdvp.user;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcTokenSessionStore implements TokenSessionStore {

    private static final int MAX_TOKEN_INSERT_ATTEMPTS = 3;

    private final SecureRandom secureRandom = new SecureRandom();
    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcTokenSessionStore(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public String create(String userId, String clientDeviceId, Instant expiresAt) {
        pruneExpiredSessions();
        for (int attempt = 0; attempt < MAX_TOKEN_INSERT_ATTEMPTS; attempt++) {
            String token = TokenSessionTokens.newToken(secureRandom);
            try {
                insertSession(token, userId, clientDeviceId, expiresAt);
                return token;
            } catch (DataIntegrityViolationException exception) {
                if (attempt == MAX_TOKEN_INSERT_ATTEMPTS - 1) {
                    throw exception;
                }
            }
        }

        throw new IllegalStateException("Unable to create token session.");
    }

    @Override
    public Optional<TokenSession> find(String token) {
        String tokenHash = TokenSessionTokens.hash(token);
        if (tokenHash.isBlank()) {
            return Optional.empty();
        }

        var results = jdbcTemplate.query(
                """
                        SELECT user_id, client_device_id, expires_at, created_at
                        FROM user_token_sessions
                        WHERE token_hash = :tokenHash
                          AND revoked_at IS NULL
                          AND expires_at > :now
                        """,
                new MapSqlParameterSource()
                        .addValue("tokenHash", tokenHash)
                        .addValue("now", now()),
                (resultSet, rowNumber) -> new TokenSession(
                        resultSet.getString("user_id"),
                        resultSet.getString("client_device_id"),
                        resultSet.getObject("expires_at", OffsetDateTime.class).toInstant(),
                        resultSet.getObject("created_at", OffsetDateTime.class).toInstant()));
        return results.stream().findFirst();
    }

    @Override
    public void remove(String token) {
        String tokenHash = TokenSessionTokens.hash(token);
        if (tokenHash.isBlank()) {
            return;
        }

        jdbcTemplate.update(
                """
                        UPDATE user_token_sessions
                        SET revoked_at = :revokedAt
                        WHERE token_hash = :tokenHash
                          AND revoked_at IS NULL
                        """,
                Map.of("tokenHash", tokenHash, "revokedAt", now()));
    }

    private void insertSession(String token, String userId, String clientDeviceId, Instant expiresAt) {
        Instant now = Instant.now();
        jdbcTemplate.update(
                """
                        INSERT INTO user_token_sessions (
                            id,
                            token_hash,
                            user_id,
                            client_device_id,
                            expires_at,
                            created_at
                        ) VALUES (
                            :id,
                            :tokenHash,
                            :userId,
                            :clientDeviceId,
                            :expiresAt,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", "session-" + UUID.randomUUID())
                        .addValue("tokenHash", TokenSessionTokens.hash(token))
                        .addValue("userId", userId)
                        .addValue("clientDeviceId", normalizeClientDeviceId(clientDeviceId))
                        .addValue("expiresAt", OffsetDateTime.ofInstant(expiresAt, ZoneOffset.UTC))
                        .addValue("createdAt", OffsetDateTime.ofInstant(now, ZoneOffset.UTC)));
    }

    private void pruneExpiredSessions() {
        jdbcTemplate.update(
                """
                        DELETE FROM user_token_sessions
                        WHERE expires_at <= :now
                           OR revoked_at IS NOT NULL
                        """,
                Map.of("now", now()));
    }

    private String normalizeClientDeviceId(String clientDeviceId) {
        String normalized = clientDeviceId == null ? "" : clientDeviceId.trim();
        return normalized.length() <= 128 ? normalized : normalized.substring(0, 128);
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }
}
