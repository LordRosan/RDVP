package com.rmf.rdvp.shared.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryService;
import com.rmf.rdvp.user.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;

@Service
public class SecurityLogService {

    private final LogEntryService logEntryService;

    public SecurityLogService(LogEntryService logEntryService) {
        this.logEntryService = logEntryService;
    }

    public void recordAccessDenied(HttpServletRequest request) {
        AuthenticatedUser actor = currentActor();
        String target = target(request);
        logEntryService.recordFailure(
                LogAction.AUTHORIZATION_DENIED,
                target,
                target,
                actor,
                "接口访问被拒绝：权限不足。");
    }

    public void recordAuthenticationFailed(HttpServletRequest request, String reason) {
        String target = target(request);
        logEntryService.recordFailure(
                LogAction.AUTHENTICATION_FAILED,
                target,
                target,
                null,
                "接口认证失败：%s。".formatted(normalizeReason(reason)));
    }

    private AuthenticatedUser currentActor() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser user)) {
            return null;
        }

        return user;
    }

    private String target(HttpServletRequest request) {
        String method = request == null ? "" : request.getMethod();
        String uri = request == null ? "" : request.getRequestURI();
        String normalized = (method + " " + uri).trim();
        return normalized.isBlank() ? "UNKNOWN" : normalized;
    }

    private String normalizeReason(String reason) {
        String normalized = reason == null ? "" : reason.trim();
        return normalized.isBlank() ? "UNAUTHORIZED" : normalized;
    }
}
