package com.rmf.rdvp.archive.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record QrVerifyRequest(
        @NotBlank @Size(max = 512) String qrContent) {
}
