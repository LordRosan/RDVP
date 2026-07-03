package com.rmf.rdvp.user.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordVerificationRequest(
        @NotBlank @Size(max = 128) String password) {
}
