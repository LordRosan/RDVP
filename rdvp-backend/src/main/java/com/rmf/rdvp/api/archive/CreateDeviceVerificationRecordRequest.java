package com.rmf.rdvp.api.archive;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateDeviceVerificationRecordRequest(
        @NotBlank @Size(max = 32) String result,
        @NotBlank @Size(max = 500) String description,
        @Size(max = 300) String remark,
        @NotBlank @Size(max = 64) String verifiedAt) {
}
