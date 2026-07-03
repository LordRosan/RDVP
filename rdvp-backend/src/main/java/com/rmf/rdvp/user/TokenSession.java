package com.rmf.rdvp.user;

import java.time.Instant;

public record TokenSession(
        String userId,
        String clientDeviceId,
        Instant expiresAt,
        Instant createdAt) {
}
