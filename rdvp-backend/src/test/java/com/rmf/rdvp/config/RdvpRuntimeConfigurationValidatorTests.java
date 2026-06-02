package com.rmf.rdvp.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class RdvpRuntimeConfigurationValidatorTests {

    @Test
    void allowsLocalProfilesToUseLocalDefaults() {
        RdvpRuntimeProperties properties = new RdvpRuntimeProperties();
        MockEnvironment environment = new MockEnvironment();
        environment.setActiveProfiles("local");

        assertThatCode(() -> new RdvpRuntimeConfigurationValidator(environment, properties).run(null))
                .doesNotThrowAnyException();
    }

    @Test
    void rejectsProductionProfileWithDefaultBootstrapPassword() {
        RdvpRuntimeProperties properties = new RdvpRuntimeProperties();
        properties.getQrCode().setSigningSecret("prod-qr-signing-secret");
        MockEnvironment environment = new MockEnvironment();
        environment.setActiveProfiles("prod");

        assertThatThrownBy(() -> new RdvpRuntimeConfigurationValidator(environment, properties).run(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("RDVP_BOOTSTRAP_PASSWORD");
    }

    @Test
    void rejectsProductionProfileWithDefaultQrSigningSecret() {
        RdvpRuntimeProperties properties = new RdvpRuntimeProperties();
        properties.getBootstrapUsers().setDefaultPassword("prod-bootstrap-password");
        MockEnvironment environment = new MockEnvironment();
        environment.setActiveProfiles("prod");

        assertThatThrownBy(() -> new RdvpRuntimeConfigurationValidator(environment, properties).run(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("RDVP_QR_SIGNING_SECRET");
    }

    @Test
    void allowsProductionProfileWithOverriddenSecrets() {
        RdvpRuntimeProperties properties = new RdvpRuntimeProperties();
        properties.getBootstrapUsers().setDefaultPassword("prod-bootstrap-password");
        properties.getQrCode().setSigningSecret("prod-qr-signing-secret");
        MockEnvironment environment = new MockEnvironment();
        environment.setActiveProfiles("prod");

        assertThatCode(() -> new RdvpRuntimeConfigurationValidator(environment, properties).run(null))
                .doesNotThrowAnyException();
    }
}
