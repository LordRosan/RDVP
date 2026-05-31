package com.rmf.rdvp.api.auth;

public record LoginResponse(
        String accessToken,
        long expiresIn,
        UserResponse user) {
}
