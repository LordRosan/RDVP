package com.rmf.rdvp.api.operations;

import jakarta.validation.constraints.NotBlank;

public record RepairReportRequest(
        @NotBlank String result,
        @NotBlank String repairedAt,
        @NotBlank String processDescription,
        String partsUsed) {
}
