package com.rmf.rdvp.shared.security;

import java.io.IOException;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import com.rmf.rdvp.shared.api.ApiResponseWriter;
import com.rmf.rdvp.shared.error.ErrorCode;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class ApiAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ApiResponseWriter responseWriter;
    private final SecurityLogService securityLogService;

    public ApiAuthenticationEntryPoint(
            ApiResponseWriter responseWriter,
            SecurityLogService securityLogService) {
        this.responseWriter = responseWriter;
        this.securityLogService = securityLogService;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException) throws IOException, ServletException {
        securityLogService.recordAuthenticationFailed(request, "MISSING_CREDENTIALS");
        responseWriter.writeError(
                request,
                response,
                HttpStatus.UNAUTHORIZED,
                ErrorCode.UNAUTHORIZED.code(),
                ErrorCode.UNAUTHORIZED.defaultMessage());
    }
}
