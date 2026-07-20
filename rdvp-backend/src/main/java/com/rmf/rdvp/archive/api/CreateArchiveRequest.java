package com.rmf.rdvp.archive.api;

import java.util.List;
import java.util.Map;

import jakarta.annotation.Nullable;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateArchiveRequest(
        @Size(max = 32) String type,
        @Size(max = 64) String deviceId,
        @Size(max = 64) String deviceCode,
        @Size(max = 500) String reason,
        Map<@Size(max = 64) String, @Valid ArchiveFieldChangePayload> changes,
        @Size(max = 5) List<@NotNull @Valid ArchiveImagePayload> images,
        @Nullable String initiatedAt) {
}
