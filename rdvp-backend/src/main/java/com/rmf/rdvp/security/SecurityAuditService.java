package com.rmf.rdvp.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.identity.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;

@Service
public class SecurityAuditService {

    private final AuditLogService auditLogService;

    public SecurityAuditService(AuditLogService auditLogService) {
        this.auditLogService = auditLogService;
    }

    public void recordAccessDenied(HttpServletRequest request) {
        AuthenticatedUser actor = currentActor();
        String target = target(request);
        auditLogService.recordFailure(
                AuditAction.AUTHORIZATION_DENIED,
                target,
                target,
                actor,
                "接口访问被拒绝：权限不足。");
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
}
