package com.rmf.rdvp.identity;

import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.rmf.rdvp.api.auth.LoginRequest;
import com.rmf.rdvp.api.auth.LoginResponse;
import com.rmf.rdvp.api.auth.UserResponse;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;

@Service
public class AuthenticationService {

    private static final Duration ACCESS_TOKEN_TTL = Duration.ofDays(7);

    private final BootstrapUserStore userStore;
    private final PasswordEncoder passwordEncoder;
    private final TokenSessionStore tokenSessionStore;

    public AuthenticationService(
            BootstrapUserStore userStore,
            PasswordEncoder passwordEncoder,
            TokenSessionStore tokenSessionStore) {
        this.userStore = userStore;
        this.passwordEncoder = passwordEncoder;
        this.tokenSessionStore = tokenSessionStore;
    }

    public LoginResponse login(LoginRequest request) {
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        BootstrapUser user = userStore.findByUsername(username)
                .filter(candidate -> passwordEncoder.matches(request.password(), candidate.passwordHash()))
                .filter(candidate -> candidate.status() == UserStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_CREDENTIALS));

        Instant expiresAt = Instant.now().plus(ACCESS_TOKEN_TTL);
        String token = tokenSessionStore.create(user.id(), request.clientDeviceId(), expiresAt);
        return new LoginResponse(token, ACCESS_TOKEN_TTL.toSeconds(), UserResponse.from(user.toAuthenticatedUser()));
    }

    public Optional<AuthenticatedUser> authenticate(String token) {
        return tokenSessionStore.find(token)
                .filter(session -> session.expiresAt().isAfter(Instant.now()))
                .flatMap(session -> userStore.findById(session.userId()))
                .filter(user -> user.status() == UserStatus.ACTIVE)
                .map(BootstrapUser::toAuthenticatedUser);
    }

    public void logout(String token) {
        tokenSessionStore.remove(token);
    }
}
