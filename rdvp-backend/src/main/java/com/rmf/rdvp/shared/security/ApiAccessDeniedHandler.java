package com.rmf.rdvp.shared.security;

import java.io.IOException;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import com.rmf.rdvp.shared.api.ApiResponseWriter;
import com.rmf.rdvp.shared.error.ErrorCode;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class ApiAccessDeniedHandler implements AccessDeniedHandler {

    private final ApiResponseWriter responseWriter;
    private final SecurityLogService securityLogService;

    public ApiAccessDeniedHandler(
            ApiResponseWriter responseWriter,
            SecurityLogService securityLogService) {
        this.responseWriter = responseWriter;
        this.securityLogService = securityLogService;
    }

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException accessDeniedException) throws IOException, ServletException {
        securityLogService.recordAccessDenied(request);
        responseWriter.writeError(
                request,
                response,
                HttpStatus.FORBIDDEN,
                ErrorCode.FORBIDDEN.code(),
                ErrorCode.FORBIDDEN.defaultMessage());
    }
}
