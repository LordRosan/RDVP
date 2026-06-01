package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;

public record DeviceArchiveUpdate(
        String deviceId,
        String name,
        String model,
        String manufacturer,
        String address,
        String updatedBy,
        OffsetDateTime updatedAt) {
}
