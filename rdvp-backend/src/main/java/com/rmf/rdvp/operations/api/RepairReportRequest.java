package com.rmf.rdvp.operations.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RepairReportRequest(
        @NotBlank @Size(max = 32) String result,
        @NotBlank @Size(max = 64) String repairedAt,
        @NotBlank @Size(max = 1000) String processDescription,
        @Size(max = 500) String partsUsed) {
}
