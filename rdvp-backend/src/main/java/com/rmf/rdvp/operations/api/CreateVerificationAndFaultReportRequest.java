package com.rmf.rdvp.operations.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateVerificationAndFaultReportRequest(
        @NotBlank @Size(max = 32) String result,
        @NotBlank @Size(max = 500) String description,
        @Size(max = 300) String remark,
        @NotBlank @Size(max = 64) String verifiedAt,
        @NotBlank @Size(max = 32) String faultType,
        @NotBlank @Size(max = 32) String severity,
        @NotBlank @Size(max = 64) String occurredAt,
        @NotBlank @Size(max = 1000) String faultDescription,
        @Size(max = 500) String sceneCondition,
        BigDecimal longitude,
        BigDecimal latitude) {
}
