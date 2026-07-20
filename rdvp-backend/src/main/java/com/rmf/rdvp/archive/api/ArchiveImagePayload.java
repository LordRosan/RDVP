package com.rmf.rdvp.archive.api;

import jakarta.validation.constraints.Size;

public record ArchiveImagePayload(
        @Size(max = 64) String id,
        @Size(max = 2_100_000) String contentBase64) {
}
