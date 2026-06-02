package com.rmf.rdvp.api.operations;

import jakarta.validation.constraints.NotBlank;

public record ReinspectionRecordRequest(
        @NotBlank String result,
        @NotBlank String reinspectedAt,
        @NotBlank String description) {
}
