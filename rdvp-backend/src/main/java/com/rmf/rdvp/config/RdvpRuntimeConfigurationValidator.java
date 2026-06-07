package com.rmf.rdvp.config;

import java.util.Arrays;
import java.util.Set;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class RdvpRuntimeConfigurationValidator implements ApplicationRunner {

    private static final String LOCAL_DEFAULT_PASSWORD = "password";
    private static final String LOCAL_DEFAULT_QR_SIGNING_SECRET = "rdvp-local-development-secret";
    private static final String LOCAL_DEFAULT_DATASOURCE_PASSWORD = "rdvp_dev_password";
    private static final Set<String> LOCAL_PROFILES = Set.of("default", "local", "dev", "test");

    private final Environment environment;
    private final RdvpRuntimeProperties runtimeProperties;

    public RdvpRuntimeConfigurationValidator(
            Environment environment,
            RdvpRuntimeProperties runtimeProperties) {
        this.environment = environment;
        this.runtimeProperties = runtimeProperties;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (usesOnlyLocalProfiles()) {
            return;
        }

        if (LOCAL_DEFAULT_PASSWORD.equals(runtimeProperties.getBootstrapUsers().getDefaultPassword())) {
            throw new IllegalStateException("RDVP_BOOTSTRAP_PASSWORD must be changed outside local profiles.");
        }

        if (LOCAL_DEFAULT_QR_SIGNING_SECRET.equals(runtimeProperties.getQrCode().getSigningSecret())) {
            throw new IllegalStateException("RDVP_QR_SIGNING_SECRET must be changed outside local profiles.");
        }

        if (LOCAL_DEFAULT_DATASOURCE_PASSWORD.equals(environment.getProperty("spring.datasource.password"))) {
            throw new IllegalStateException("RDVP_DATASOURCE_PASSWORD must be changed outside local profiles.");
        }
    }

    private boolean usesOnlyLocalProfiles() {
        String[] activeProfiles = environment.getActiveProfiles();
        if (activeProfiles.length == 0) {
            return false;
        }

        return Arrays.stream(activeProfiles)
                .map(profile -> profile == null ? "" : profile.trim().toLowerCase())
                .allMatch(LOCAL_PROFILES::contains);
    }
}
