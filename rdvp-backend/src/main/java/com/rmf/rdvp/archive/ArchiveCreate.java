package com.rmf.rdvp.archive;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ArchiveCreate(
        String id,
        String deviceCode,
        String name,
        String model,
        String manufacturer,
        String status,
        String address,
        BigDecimal longitude,
        BigDecimal latitude,
        String createdBy,
        OffsetDateTime createdAt) {
}
