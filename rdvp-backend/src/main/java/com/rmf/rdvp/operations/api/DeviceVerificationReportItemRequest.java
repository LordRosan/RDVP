package com.rmf.rdvp.operations.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DeviceVerificationReportItemRequest(
        @NotBlank @Size(max = 64) String itemCode,
        @NotBlank @Size(max = 100) String itemName,
        @NotBlank @Size(max = 32) String result) {
}
