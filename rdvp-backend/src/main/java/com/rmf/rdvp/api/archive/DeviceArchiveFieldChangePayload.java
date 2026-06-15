package com.rmf.rdvp.api.archive;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record DeviceArchiveFieldChangePayload(
        @Size(max = 500) String oldValue,
        @NotNull @Size(max = 500) String newValue) {
}
