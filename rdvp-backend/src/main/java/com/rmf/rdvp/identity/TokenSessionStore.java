package com.rmf.rdvp.identity;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.stereotype.Repository;

@Repository
public class TokenSessionStore {

    private static final int TOKEN_BYTES = 32;
    private static final Base64.Encoder TOKEN_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final SecureRandom secureRandom = new SecureRandom();
    private final ConcurrentMap<String, TokenSession> sessions = new ConcurrentHashMap<>();

    public String create(String userId, String clientDeviceId, Instant expiresAt) {
        String token = newToken();
        sessions.put(token, new TokenSession(token, userId, clientDeviceId, expiresAt, Instant.now()));
        return token;
    }

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

    public void remove(String token) {
        sessions.remove(token);
    }

    private String newToken() {
        byte[] tokenBytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(tokenBytes);
        return TOKEN_ENCODER.encodeToString(tokenBytes);
    }
}
