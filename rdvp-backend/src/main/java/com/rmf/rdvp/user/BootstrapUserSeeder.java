package com.rmf.rdvp.user;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.rmf.rdvp.shared.config.RdvpRuntimeProperties;

@Component
@Profile("!test")
public class BootstrapUserSeeder implements ApplicationRunner {

    private final JdbcUserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;
    private final RdvpRuntimeProperties runtimeProperties;

    public BootstrapUserSeeder(
            JdbcUserAccountRepository userAccountRepository,
            PasswordEncoder passwordEncoder,
            RdvpRuntimeProperties runtimeProperties) {
        this.userAccountRepository = userAccountRepository;
        this.passwordEncoder = passwordEncoder;
        this.runtimeProperties = runtimeProperties;
    }

    @Override
    public void run(ApplicationArguments args) {
        String defaultPassword = runtimeProperties.getBootstrapUsers().getDefaultPassword();
        BootstrapUserDefinitions.createUsers(passwordEncoder, defaultPassword)
                .forEach(userAccountRepository::ensureBootstrapUser);
    }
}
