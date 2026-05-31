package com.rmf.rdvp.identity;

import java.time.Instant;

public record TokenSession(
        String token,
        String userId,
        String clientDeviceId,
        Instant expiresAt,
        Instant createdAt) {
}
