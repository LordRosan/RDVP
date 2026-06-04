package com.rmf.rdvp.api.archive;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;

public record CreateDeviceVerificationFaultReportRequest(
        @NotBlank String result,
        @NotBlank String description,
        String remark,
        @NotBlank String verifiedAt,
        @NotBlank String faultType,
        @NotBlank String severity,
        @NotBlank String occurredAt,
        @NotBlank String faultDescription,
        String sceneCondition,
        BigDecimal longitude,
        BigDecimal latitude) {
}
