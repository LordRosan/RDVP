package com.rmf.rdvp.security;

import java.util.Optional;

import jakarta.servlet.http.HttpServletRequest;

public final class BearerTokens {

    private static final String PREFIX = "Bearer ";

    private BearerTokens() {
    }

    public static Optional<String> resolve(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || !authorization.startsWith(PREFIX)) {
            return Optional.empty();
        }

        String token = authorization.substring(PREFIX.length()).trim();
        if (token.isEmpty()) {
            return Optional.empty();
        }

        return Optional.of(token);
    }
}
