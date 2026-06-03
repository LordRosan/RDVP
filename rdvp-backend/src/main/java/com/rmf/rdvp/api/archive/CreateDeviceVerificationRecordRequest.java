package com.rmf.rdvp.api.archive;

import jakarta.validation.constraints.NotBlank;

public record CreateDeviceVerificationRecordRequest(
        @NotBlank String result,
        @NotBlank String description,
        String remark,
        @NotBlank String verifiedAt) {
}
