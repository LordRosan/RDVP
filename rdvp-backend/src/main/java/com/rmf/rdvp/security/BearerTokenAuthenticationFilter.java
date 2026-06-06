package com.rmf.rdvp.security;

import java.io.IOException;

import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.rmf.rdvp.api.common.ApiResponseWriter;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.AuthenticationService;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class BearerTokenAuthenticationFilter extends OncePerRequestFilter {

    private final AuthenticationService authenticationService;
    private final ApiResponseWriter responseWriter;
    private final SecurityAuditService securityAuditService;

    public BearerTokenAuthenticationFilter(
            AuthenticationService authenticationService,
            ApiResponseWriter responseWriter,
            SecurityAuditService securityAuditService) {
        this.authenticationService = authenticationService;
        this.responseWriter = responseWriter;
        this.securityAuditService = securityAuditService;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        var token = BearerTokens.resolve(request);
        if (token.isEmpty()) {
            filterChain.doFilter(request, response);
            return;
        }

        var user = authenticationService.authenticate(token.get());
        if (user.isEmpty()) {
            SecurityContextHolder.clearContext();
            securityAuditService.recordAuthenticationFailed(request, "INVALID_OR_EXPIRED_TOKEN");
            responseWriter.writeError(
                    request,
                    response,
                    HttpStatus.UNAUTHORIZED,
                    ErrorCode.UNAUTHORIZED.code(),
                    ErrorCode.UNAUTHORIZED.defaultMessage());
            return;
        }

        SecurityContextHolder.getContext().setAuthentication(toAuthentication(user.get()));
        filterChain.doFilter(request, response);
    }

    private UsernamePasswordAuthenticationToken toAuthentication(AuthenticatedUser user) {
        var authorities = user.permissions()
                .stream()
                .map(permission -> new SimpleGrantedAuthority(permission.name()))
                .toList();
        return new UsernamePasswordAuthenticationToken(user, null, authorities);
    }
}
