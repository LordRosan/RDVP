package com.rmf.rdvp.user;

import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.rmf.rdvp.user.api.LoginRequest;
import com.rmf.rdvp.user.api.LoginResponse;
import com.rmf.rdvp.user.api.UserResponse;
import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryService;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;

@Service
public class AuthenticationService {

    private static final Duration ACCESS_TOKEN_TTL = Duration.ofDays(7);
    private static final Duration LOGIN_ATTEMPT_LOCK_DURATION = Duration.ofMinutes(15);
    private static final Duration PASSWORD_VERIFICATION_LOCK_DURATION = Duration.ofHours(12);
    private static final Duration SENSITIVE_OPERATION_VERIFICATION_TTL = Duration.ofMinutes(5);
    private static final int MAX_LOGIN_FAILURES = 5;
    private static final int MAX_PASSWORD_VERIFICATION_FAILURES = 5;

    private final UserAccountRepository userStore;
    private final PasswordEncoder passwordEncoder;
    private final TokenSessionStore tokenSessionStore;
    private final LoginAttemptStore loginAttemptStore;
    private final PasswordVerificationAttemptStore passwordVerificationAttemptStore;
    private final LogEntryService logEntryService;

    public AuthenticationService(
            UserAccountRepository userStore,
            PasswordEncoder passwordEncoder,
            TokenSessionStore tokenSessionStore,
            LoginAttemptStore loginAttemptStore,
            PasswordVerificationAttemptStore passwordVerificationAttemptStore,
            LogEntryService logEntryService) {
        this.userStore = userStore;
        this.passwordEncoder = passwordEncoder;
        this.tokenSessionStore = tokenSessionStore;
        this.loginAttemptStore = loginAttemptStore;
        this.passwordVerificationAttemptStore = passwordVerificationAttemptStore;
        this.logEntryService = logEntryService;
    }

    public LoginResponse login(LoginRequest request) {
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        Instant now = Instant.now();
        if (isLoginLocked(username, now)) {
            recordLoginFailure(username, Optional.empty());
            throw new BusinessException(
                    ErrorCode.RATE_LIMITED,
                    "Too many login attempts. Please retry later.");
        }

        Optional<BootstrapUser> optionalUser = userStore.findByUsername(username);
        if (optionalUser.isEmpty() || optionalUser.get().status() != UserStatus.ACTIVE) {
            recordLoginFailure(username, optionalUser);
            throw new BusinessException(ErrorCode.ACCOUNT_INCORRECT);
        }

        if (!passwordEncoder.matches(request.password(), optionalUser.get().passwordHash())) {
            registerLoginFailure(username, now);
            recordLoginFailure(username, optionalUser);
            throw new BusinessException(ErrorCode.PASSWORD_INCORRECT);
        }

        loginAttemptStore.clear(username);
        BootstrapUser user = optionalUser.get();
        Instant expiresAt = now.plus(ACCESS_TOKEN_TTL);
        String token = tokenSessionStore.create(user.id(), request.clientDeviceId(), expiresAt);
        AuthenticatedUser authenticatedUser = user.toAuthenticatedUser();
        logEntryService.recordSuccess(
                LogAction.AUTH_LOGIN,
                user.id(),
                user.username(),
                user.id(),
                user.displayName(),
                "用户登录成功。");
        return new LoginResponse(token, ACCESS_TOKEN_TTL.toSeconds(), UserResponse.from(authenticatedUser));
    }

    private void recordLoginFailure(String username, Optional<BootstrapUser> optionalUser) {
        logEntryService.recordFailure(
                LogAction.AUTH_LOGIN,
                optionalUser.map(BootstrapUser::id).orElse(null),
                username,
                optionalUser.map(BootstrapUser::id).orElse(null),
                optionalUser.map(BootstrapUser::displayName).orElse(null),
                "用户登录失败。");
    }

    private boolean isLoginLocked(String username, Instant now) {
        Optional<LoginAttempt> optionalAttempt = loginAttemptStore.find(username);
        if (optionalAttempt.isEmpty() || optionalAttempt.get().lockedUntil() == null) {
            return false;
        }

        LoginAttempt attempt = optionalAttempt.get();
        if (attempt.lockedUntil().isAfter(now)) {
            return true;
        }

        loginAttemptStore.clear(username);
        return false;
    }

    private void registerLoginFailure(String username, Instant now) {
        loginAttemptStore.registerFailure(
                username,
                now,
                LOGIN_ATTEMPT_LOCK_DURATION,
                MAX_LOGIN_FAILURES);
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
            logEntryService.recordFailure(
                    LogAction.AUTH_PASSWORD_VERIFY,
                    authenticatedUser.id(),
                    authenticatedUser.username(),
                    authenticatedUser,
                    "用户密码复核失败：PASSWORD_VERIFICATION_LOCKED。");
            throw new BusinessException(
                    ErrorCode.PASSWORD_VERIFICATION_LOCKED,
                    "Password verification is locked. Please retry later.");
        }

        boolean verified = userStore.findById(authenticatedUser.id())
                .filter(user -> user.status() == UserStatus.ACTIVE)
                .filter(user -> passwordEncoder.matches(password, user.passwordHash()))
                .isPresent();
        if (verified) {
            passwordVerificationAttemptStore.markVerified(
                    authenticatedUser.id(),
                    now,
                    SENSITIVE_OPERATION_VERIFICATION_TTL);
            logEntryService.recordSuccess(
                    LogAction.AUTH_PASSWORD_VERIFY,
                    authenticatedUser.id(),
                    authenticatedUser.username(),
                    authenticatedUser,
                    "用户密码复核成功。");
            return true;
        }

        registerPasswordVerificationFailure(authenticatedUser.id(), now);
        logEntryService.recordFailure(
                LogAction.AUTH_PASSWORD_VERIFY,
                authenticatedUser.id(),
                authenticatedUser.username(),
                authenticatedUser,
                "用户密码复核失败：PASSWORD_INCORRECT。");
        return false;
    }

    public void requireRecentPasswordVerification(AuthenticatedUser authenticatedUser) {
        if (authenticatedUser == null || !hasRecentPasswordVerification(authenticatedUser.id(), Instant.now())) {
            throw new BusinessException(
                    ErrorCode.SENSITIVE_OPERATION_VERIFICATION_REQUIRED,
                    "Recent password verification is required before submitting this sensitive operation.");
        }
    }

    public void consumeRecentPasswordVerification(AuthenticatedUser authenticatedUser) {
        requireRecentPasswordVerification(authenticatedUser);
        passwordVerificationAttemptStore.clear(authenticatedUser.id());
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

    private boolean hasRecentPasswordVerification(String userId, Instant now) {
        Optional<PasswordVerificationAttempt> optionalAttempt = passwordVerificationAttemptStore.find(userId);
        if (optionalAttempt.isEmpty() || optionalAttempt.get().verifiedUntil() == null) {
            return false;
        }

        return optionalAttempt.get().verifiedUntil().isAfter(now);
    }

    private void registerPasswordVerificationFailure(String userId, Instant now) {
        passwordVerificationAttemptStore.registerFailure(
                userId,
                now,
                PASSWORD_VERIFICATION_LOCK_DURATION,
                MAX_PASSWORD_VERIFICATION_FAILURES);
    }
}
