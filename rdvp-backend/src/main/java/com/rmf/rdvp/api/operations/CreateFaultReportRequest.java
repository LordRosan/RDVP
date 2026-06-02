package com.rmf.rdvp.api.operations;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;

public record CreateFaultReportRequest(
        @NotBlank String deviceCode,
        @NotBlank String faultType,
        @NotBlank String severity,
        @NotBlank String occurredAt,
        @NotBlank String description,
        String sceneCondition,
        BigDecimal longitude,
        BigDecimal latitude) {
}
