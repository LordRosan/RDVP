package com.rmf.rdvp.api.system;

import java.time.Instant;

public record SystemHealthResponse(
        String status,
        String service,
        String version,
        String environment,
        Instant startedAt) {
}
