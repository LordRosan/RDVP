package com.rmf.rdvp.api.common;

import java.util.UUID;

import jakarta.servlet.http.HttpServletRequest;

public final class RequestIds {

    public static final String HEADER_NAME = "X-Request-Id";

    private RequestIds() {
    }

    public static String resolve(HttpServletRequest request) {
        String requestId = request.getHeader(HEADER_NAME);
        if (requestId == null || requestId.isBlank()) {
            return UUID.randomUUID().toString();
        }

        return requestId;
    }
}
