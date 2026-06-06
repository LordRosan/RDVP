package com.rmf.rdvp.api.sync;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record OfflineSyncBatchRequest(
        @NotBlank @Size(max = 128) String clientBatchId,
        @NotEmpty @Size(max = 20) List<@Valid OfflineSyncRecordRequest> records) {
}
