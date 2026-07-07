package com.rmf.rdvp.operations.api;

import java.math.BigDecimal;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record CreateAbnormalVerificationSubmissionRequest(
        @Size(max = 32) String result,
        @NotBlank @Size(max = 32) String verificationType,
        @NotBlank @Size(max = 32) String deviceStatus,
        @NotBlank @Size(max = 32) String verificationMethod,
        @NotEmpty @Size(max = 20) List<@Valid DeviceVerificationReportItemRequest> items,
        @NotBlank @Size(max = 500) String description,
        @Size(max = 300) String remark,
        @NotBlank @Size(max = 64) String verifiedAt,
        @NotBlank @Size(max = 32) String faultType,
        @NotBlank @Size(max = 64) String faultSubtype,
        @NotBlank @Size(max = 32) String severity,
        @NotBlank @Size(max = 64) String occurredAt,
        @NotBlank @Size(max = 1000) String faultDescription,
        @Size(max = 500) String sceneCondition,
        BigDecimal longitude,
        BigDecimal latitude) {
}
