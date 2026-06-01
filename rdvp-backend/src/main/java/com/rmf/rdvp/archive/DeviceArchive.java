package com.rmf.rdvp.archive;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record DeviceArchive(
        String id,
        String deviceCode,
        String name,
        String model,
        String manufacturer,
        String status,
        String address,
        BigDecimal longitude,
        BigDecimal latitude,
        OffsetDateTime lastVerificationTime,
        ChangeState changeState) {

    public record ChangeState(
            boolean locked,
            String pendingRequestId,
            OffsetDateTime freezeUntil) {
    }
}
