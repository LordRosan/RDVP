package com.rmf.rdvp.api.auth;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.AuthenticationService;
import com.rmf.rdvp.security.BearerTokens;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthenticationService authenticationService;

    public AuthController(AuthenticationService authenticationService) {
        this.authenticationService = authenticationService;
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(
            @Valid @RequestBody LoginRequest requestBody,
            HttpServletRequest request) {
        LoginResponse response = authenticationService.login(requestBody);
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> me(Authentication authentication, HttpServletRequest request) {
        AuthenticatedUser user = requireUser(authentication);
        return ResponseEntity.ok(ApiResponse.success(UserResponse.from(user), RequestIds.resolve(request)));
    }

    @PostMapping("/password-verification")
    public ResponseEntity<ApiResponse<PasswordVerificationResponse>> verifyPassword(
            @Valid @RequestBody PasswordVerificationRequest requestBody,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser user = requireUser(authentication);
        boolean verified = authenticationService.verifyPassword(user, requestBody.password());
        if (!verified) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }

        return ResponseEntity.ok(ApiResponse.success(new PasswordVerificationResponse(true), RequestIds.resolve(request)));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<LogoutResponse>> logout(HttpServletRequest request) {
        String token = BearerTokens.resolve(request)
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED));
        authenticationService.logout(token);
        return ResponseEntity.ok(ApiResponse.success(new LogoutResponse(true), RequestIds.resolve(request)));
    }

    private AuthenticatedUser requireUser(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser user)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }

        return user;
    }
}
