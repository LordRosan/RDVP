package com.rmf.rdvp.api.archive;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ReviewDeviceChangeRequest(
        @NotBlank @Size(max = 32) String decision,
        @Size(max = 64) String reviewedAt,
        @Size(max = 500) String reviewComment) {
}
