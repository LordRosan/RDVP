package com.rmf.rdvp.shared.system;

import java.time.Instant;

public record SystemHealthResponse(
        String status,
        String service,
        String version,
        String environment,
        Instant startedAt) {
}
