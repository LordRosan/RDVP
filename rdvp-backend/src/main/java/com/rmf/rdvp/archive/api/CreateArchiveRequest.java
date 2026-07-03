package com.rmf.rdvp.archive.api;

import java.util.Map;

import jakarta.annotation.Nullable;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;

public record CreateArchiveRequest(
        @Size(max = 32) String type,
        @Size(max = 64) String deviceId,
        @Size(max = 64) String deviceCode,
        @Size(max = 500) String reason,
        Map<@Size(max = 64) String, @Valid ArchiveFieldChangePayload> changes,
        @Nullable String initiatedAt) {
}
