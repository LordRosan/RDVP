package com.rmf.rdvp.user;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryTokenSessionStore implements TokenSessionStore {

    private final SecureRandom secureRandom = new SecureRandom();
    private final ConcurrentMap<String, TokenSession> sessions = new ConcurrentHashMap<>();

    @Override
    public String create(String userId, String clientDeviceId, Instant expiresAt) {
        pruneExpiredSessions();
        String token = TokenSessionTokens.newToken(secureRandom);
        sessions.put(token, new TokenSession(userId, clientDeviceId, expiresAt, Instant.now()));
        return token;
    }

    @Override
    public Optional<TokenSession> find(String token) {
        TokenSession session = sessions.get(token);
        if (session == null) {
            return Optional.empty();
        }

        if (!session.expiresAt().isAfter(Instant.now())) {
            sessions.remove(token);
            return Optional.empty();
        }

        return Optional.of(session);
    }

    @Override
    public void remove(String token) {
        sessions.remove(token);
    }

    private void pruneExpiredSessions() {
        Instant now = Instant.now();
        sessions.entrySet().removeIf(entry -> !entry.getValue().expiresAt().isAfter(now));
    }
}
