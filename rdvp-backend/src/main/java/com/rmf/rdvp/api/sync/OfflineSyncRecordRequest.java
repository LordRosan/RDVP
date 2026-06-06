package com.rmf.rdvp.api.sync;

import java.time.OffsetDateTime;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record OfflineSyncRecordRequest(
        @NotBlank @Size(max = 128) String clientRecordId,
        @NotBlank @Size(max = 64) String recordType,
        @NotNull Object payload,
        @NotNull OffsetDateTime createdOfflineAt) {
}
