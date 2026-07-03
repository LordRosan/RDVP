package com.rmf.rdvp.user.api;

public record LoginResponse(
        String accessToken,
        long expiresIn,
        UserResponse user) {
}
