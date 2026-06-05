package com.rmf.rdvp.identity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

final class TokenSessionTokens {

    private static final int TOKEN_BYTES = 32;
    private static final Base64.Encoder TOKEN_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private TokenSessionTokens() {
    }

    static String newToken(SecureRandom secureRandom) {
        byte[] tokenBytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(tokenBytes);
        return TOKEN_ENCODER.encodeToString(tokenBytes);
    }

    static String hash(String token) {
        if (token == null || token.isBlank()) {
            return "";
        }

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.trim().getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to hash access token.", exception);
        }
    }
}
