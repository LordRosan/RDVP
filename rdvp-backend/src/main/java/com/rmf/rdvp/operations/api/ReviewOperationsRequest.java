package com.rmf.rdvp.operations.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ReviewOperationsRequest(
        @NotBlank @Size(max = 32) String decision,
        @NotBlank @Size(max = 64) String reviewedAt,
        @Size(max = 500) String reviewComment) {
}
