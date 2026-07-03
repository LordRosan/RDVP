package com.rmf.rdvp.archive.api;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ArchiveFieldChangePayload(
        @Size(max = 500) String oldValue,
        @NotNull @Size(max = 500) String newValue) {
}
