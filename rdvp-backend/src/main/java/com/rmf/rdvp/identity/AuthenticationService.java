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
    private final PasswordVerificationAttemptStore passwordVerificationAttemptStore;
    private final AuditLogService auditLogService;

    public AuthenticationService(
            UserAccountRepository userStore,
            PasswordEncoder passwordEncoder,
            TokenSessionStore tokenSessionStore,
            PasswordVerificationAttemptStore passwordVerificationAttemptStore,
            AuditLogService auditLogService) {
        this.userStore = userStore;
        this.passwordEncoder = passwordEncoder;
        this.tokenSessionStore = tokenSessionStore;
        this.passwordVerificationAttemptStore = passwordVerificationAttemptStore;
        this.auditLogService = auditLogService;
    }

    public LoginResponse login(LoginRequest request) {
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        Optional<BootstrapUser> optionalUser = userStore.findByUsername(username);
        if (optionalUser.isEmpty()
                || optionalUser.get().status() != UserStatus.ACTIVE
                || !passwordEncoder.matches(request.password(), optionalUser.get().passwordHash())) {
            recordLoginFailure(username, optionalUser);
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }

        BootstrapUser user = optionalUser.get();
        Instant expiresAt = Instant.now().plus(ACCESS_TOKEN_TTL);
        String token = tokenSessionStore.create(user.id(), request.clientDeviceId(), expiresAt);
        AuthenticatedUser authenticatedUser = user.toAuthenticatedUser();
        auditLogService.recordSuccess(
                AuditAction.AUTH_LOGIN,
                user.id(),
                user.username(),
                user.id(),
                user.displayName(),
                "用户登录成功。");
        return new LoginResponse(token, ACCESS_TOKEN_TTL.toSeconds(), UserResponse.from(authenticatedUser));
    }

    private void recordLoginFailure(String username, Optional<BootstrapUser> optionalUser) {
        auditLogService.recordFailure(
                AuditAction.AUTH_LOGIN,
                optionalUser.map(BootstrapUser::id).orElse(null),
                username,
                optionalUser.map(BootstrapUser::id).orElse(null),
                optionalUser.map(BootstrapUser::displayName).orElse(null),
                "用户登录失败。");
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
            passwordVerificationAttemptStore.clear(authenticatedUser.id());
            return true;
        }

        registerPasswordVerificationFailure(authenticatedUser.id(), now);
        return false;
    }

    public void logout(String token) {
        tokenSessionStore.remove(token);
    }

    private boolean isPasswordVerificationLocked(String userId, Instant now) {
        Optional<PasswordVerificationAttempt> optionalAttempt = passwordVerificationAttemptStore.find(userId);
        if (optionalAttempt.isEmpty() || optionalAttempt.get().lockedUntil() == null) {
            return false;
        }

        PasswordVerificationAttempt attempt = optionalAttempt.get();
        if (attempt.lockedUntil().isAfter(now)) {
            return true;
        }

        passwordVerificationAttemptStore.clear(userId);
        return false;
    }

    private void registerPasswordVerificationFailure(String userId, Instant now) {
        passwordVerificationAttemptStore.registerFailure(
                userId,
                now,
                PASSWORD_VERIFICATION_LOCK_DURATION,
                MAX_PASSWORD_VERIFICATION_FAILURES);
    }
}
