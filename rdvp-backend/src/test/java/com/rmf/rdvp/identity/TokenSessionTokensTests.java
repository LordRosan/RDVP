package com.rmf.rdvp.identity;

import static org.assertj.core.api.Assertions.assertThat;

import java.security.SecureRandom;

import org.junit.jupiter.api.Test;

class TokenSessionTokensTests {

    @Test
    void hashesAccessTokenBeforeStorage() {
        String token = TokenSessionTokens.newToken(new SecureRandom());
        String hash = TokenSessionTokens.hash(token);

        assertThat(token).isNotBlank();
        assertThat(hash).hasSize(64);
        assertThat(hash).isNotEqualTo(token);
        assertThat(TokenSessionTokens.hash(token)).isEqualTo(hash);
    }
}
