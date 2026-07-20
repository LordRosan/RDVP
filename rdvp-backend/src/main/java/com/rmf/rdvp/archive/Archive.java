package com.rmf.rdvp.archive;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

public record Archive(
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
        OffsetDateTime lastVerificationTime,
        ArchiveRequestState archiveRequestState) {

    public record ArchiveRequestState(
            boolean locked,
            String pendingRequestId,
            OffsetDateTime freezeUntil) {
    }
}
