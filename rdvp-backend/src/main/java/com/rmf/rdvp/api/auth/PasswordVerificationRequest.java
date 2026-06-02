package com.rmf.rdvp.api.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordVerificationRequest(
        @NotBlank @Size(max = 128) String password) {
}
