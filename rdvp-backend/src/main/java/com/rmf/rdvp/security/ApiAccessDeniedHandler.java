package com.rmf.rdvp.security;

import java.io.IOException;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import com.rmf.rdvp.api.common.ApiResponseWriter;
import com.rmf.rdvp.domain.common.ErrorCode;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class ApiAccessDeniedHandler implements AccessDeniedHandler {

    private final ApiResponseWriter responseWriter;

    public ApiAccessDeniedHandler(ApiResponseWriter responseWriter) {
        this.responseWriter = responseWriter;
    }

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException accessDeniedException) throws IOException, ServletException {
        responseWriter.writeError(
                request,
                response,
                HttpStatus.FORBIDDEN,
                ErrorCode.FORBIDDEN.code(),
                ErrorCode.FORBIDDEN.defaultMessage());
    }
}
