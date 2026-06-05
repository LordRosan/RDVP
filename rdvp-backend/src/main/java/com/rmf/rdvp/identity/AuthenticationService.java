package com.rmf.rdvp.identity;

import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.rmf.rdvp.api.auth.LoginRequest;
import com.rmf.rdvp.api.auth.LoginResponse;
import com.rmf.rdvp.api.auth.UserResponse;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;

@Service
public class AuthenticationService {

    private static final Duration ACCESS_TOKEN_TTL = Duration.ofDays(7);
    private static final Duration PASSWORD_VERIFICATION_LOCK_DURATION = Duration.ofHours(12);
    private static final int MAX_PASSWORD_VERIFICATION_FAILURES = 5;

    private final UserAccountRepository userStore;
    private final PasswordEncoder passwordEncoder;
    private final TokenSessionStore tokenSessionStore;
    private final AuditLogService auditLogService;
    private final ConcurrentMap<String, PasswordVerificationAttempt> passwordVerificationAttempts = new ConcurrentHashMap<>();

    public AuthenticationService(
            UserAccountRepository userStore,
            PasswordEncoder passwordEncoder,
            TokenSessionStore tokenSessionStore,
            AuditLogService auditLogService) {
        this.userStore = userStore;
        this.passwordEncoder = passwordEncoder;
        this.tokenSessionStore = tokenSessionStore;
        this.auditLogService = auditLogService;
    }

    public LoginResponse login(LoginRequest request) {
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        BootstrapUser user = userStore.findByUsername(username)
                .filter(candidate -> passwordEncoder.matches(request.password(), candidate.passwordHash()))
                .filter(candidate -> candidate.status() == UserStatus.ACTIVE)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_CREDENTIALS));

        Instant expiresAt = Instant.now().plus(ACCESS_TOKEN_TTL);
        String token = tokenSessionStore.create(user.id(), request.clientDeviceId(), expiresAt);
        AuthenticatedUser authenticatedUser = user.toAuthenticatedUser();
        auditLogService.recordSuccess(
                AuditAction.AUTH_LOGIN,
                user.id(),
                user.username(),
                user.id(),
                user.displayName(),
                "User login succeeded.");
        return new LoginResponse(token, ACCESS_TOKEN_TTL.toSeconds(), UserResponse.from(authenticatedUser));
    }

    public Optional<AuthenticatedUser> authenticate(String token) {
        return tokenSessionStore.find(token)
                .filter(session -> session.expiresAt().isAfter(Instant.now()))
                .flatMap(session -> userStore.findById(session.userId()))
                .filter(user -> user.status() == UserStatus.ACTIVE)
                .map(BootstrapUser::toAuthenticatedUser);
    }

    public boolean verifyPassword(AuthenticatedUser authenticatedUser, String password) {
        if (authenticatedUser == null || password == null || password.isBlank()) {
            return false;
        }

        Instant now = Instant.now();
        if (isPasswordVerificationLocked(authenticatedUser.id(), now)) {
            throw new BusinessException(
                    ErrorCode.PASSWORD_VERIFICATION_LOCKED,
                    "Password verification is locked. Please retry later.");
        }

        boolean verified = userStore.findById(authenticatedUser.id())
                .filter(user -> user.status() == UserStatus.ACTIVE)
                .filter(user -> passwordEncoder.matches(password, user.passwordHash()))
                .isPresent();
        if (verified) {
            passwordVerificationAttempts.remove(authenticatedUser.id());
            return true;
        }

        registerPasswordVerificationFailure(authenticatedUser.id(), now);
        return false;
    }

    public void logout(String token) {
        tokenSessionStore.remove(token);
    }

    private boolean isPasswordVerificationLocked(String userId, Instant now) {
        PasswordVerificationAttempt attempt = passwordVerificationAttempts.get(userId);
        if (attempt == null || attempt.lockedUntil() == null) {
            return false;
        }

        if (attempt.lockedUntil().isAfter(now)) {
            return true;
        }

        passwordVerificationAttempts.remove(userId);
        return false;
    }

    private void registerPasswordVerificationFailure(String userId, Instant now) {
        passwordVerificationAttempts.compute(userId, (key, current) -> {
            int failedCount = current == null ? 1 : current.failedCount() + 1;
            Instant lockedUntil = failedCount >= MAX_PASSWORD_VERIFICATION_FAILURES
                    ? now.plus(PASSWORD_VERIFICATION_LOCK_DURATION)
                    : null;
            return new PasswordVerificationAttempt(failedCount, lockedUntil);
        });
    }

    private record PasswordVerificationAttempt(int failedCount, Instant lockedUntil) {
    }
}
