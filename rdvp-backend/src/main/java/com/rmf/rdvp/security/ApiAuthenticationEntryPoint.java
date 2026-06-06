package com.rmf.rdvp.security;

import java.io.IOException;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import com.rmf.rdvp.api.common.ApiResponseWriter;
import com.rmf.rdvp.domain.common.ErrorCode;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class ApiAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ApiResponseWriter responseWriter;
    private final SecurityAuditService securityAuditService;

    public ApiAuthenticationEntryPoint(
            ApiResponseWriter responseWriter,
            SecurityAuditService securityAuditService) {
        this.responseWriter = responseWriter;
        this.securityAuditService = securityAuditService;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException) throws IOException, ServletException {
        securityAuditService.recordAuthenticationFailed(request, "MISSING_CREDENTIALS");
        responseWriter.writeError(
                request,
                response,
                HttpStatus.UNAUTHORIZED,
                ErrorCode.UNAUTHORIZED.code(),
                ErrorCode.UNAUTHORIZED.defaultMessage());
    }
}
