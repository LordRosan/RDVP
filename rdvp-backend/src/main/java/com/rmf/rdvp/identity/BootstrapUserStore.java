package com.rmf.rdvp.identity;

import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Repository;

import com.rmf.rdvp.config.RdvpRuntimeProperties;

@Repository
@Profile("test")
public class BootstrapUserStore implements UserAccountRepository {

    private final Map<String, BootstrapUser> usersById;
    private final Map<String, BootstrapUser> usersByUsername;

    public BootstrapUserStore(PasswordEncoder passwordEncoder, RdvpRuntimeProperties runtimeProperties) {
        String defaultPassword = runtimeProperties.getBootstrapUsers().getDefaultPassword();
        var users = BootstrapUserDefinitions.createUsers(passwordEncoder, defaultPassword);

        this.usersById = users.stream().collect(Collectors.toUnmodifiableMap(BootstrapUser::id, Function.identity()));
        this.usersByUsername = users.stream()
                .collect(Collectors.toUnmodifiableMap(BootstrapUser::username, Function.identity()));
    }

    @Override
    public Optional<BootstrapUser> findByUsername(String username) {
        return Optional.ofNullable(usersByUsername.get(username));
    }

    @Override
    public Optional<BootstrapUser> findById(String id) {
        return Optional.ofNullable(usersById.get(id));
    }
}
