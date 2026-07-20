package com.rmf.rdvp.archive;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

public record ArchiveCreate(
        String id,
        String deviceCode,
        String name,
        String deviceType,
        String model,
        String manufacturer,
        LocalDate commissionedAt,
        String managementDepartment,
        String status,
        String address,
        BigDecimal longitude,
        BigDecimal latitude,
        String createdBy,
        OffsetDateTime createdAt) {
}
