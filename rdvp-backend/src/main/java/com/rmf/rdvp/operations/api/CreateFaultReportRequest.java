package com.rmf.rdvp.operations.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateFaultReportRequest(
        @NotBlank @Size(max = 64) String deviceCode,
        @NotBlank @Size(max = 32) String faultType,
        @NotBlank @Size(max = 32) String severity,
        @NotBlank @Size(max = 64) String occurredAt,
        @NotBlank @Size(max = 1000) String description,
        @Size(max = 500) String sceneCondition,
        BigDecimal longitude,
        BigDecimal latitude) {
}
