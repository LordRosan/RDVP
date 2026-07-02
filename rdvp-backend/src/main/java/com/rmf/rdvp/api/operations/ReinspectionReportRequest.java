package com.rmf.rdvp.api.operations;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ReinspectionReportRequest(
        @NotBlank @Size(max = 32) String result,
        @NotBlank @Size(max = 64) String reinspectedAt,
        @NotBlank @Size(max = 800) String description) {
}
