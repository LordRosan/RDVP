package com.rmf.rdvp.api.archive;

import java.util.Map;

import jakarta.annotation.Nullable;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;

public record CreateDeviceArchiveChangeRequest(
        @Size(max = 32) String type,
        @Size(max = 64) String deviceId,
        @Size(max = 64) String deviceCode,
        @Size(max = 500) String reason,
        Map<@Size(max = 64) String, @Valid DeviceArchiveChangeValueRequest> changes,
        @Nullable String initiatedAt) {
}
