package com.rmf.rdvp.archive;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record ArchiveUpdate(
        String deviceId,
        String name,
        String deviceType,
        String model,
        String manufacturer,
        LocalDate commissionedAt,
        String managementDepartment,
        String address,
        String updatedBy,
        OffsetDateTime updatedAt) {
}
