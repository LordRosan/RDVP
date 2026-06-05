package com.rmf.rdvp.identity;

import java.time.Instant;
import java.util.Optional;

public interface TokenSessionStore {

    String create(String userId, String clientDeviceId, Instant expiresAt);

    Optional<TokenSession> find(String token);

    void remove(String token);
}
