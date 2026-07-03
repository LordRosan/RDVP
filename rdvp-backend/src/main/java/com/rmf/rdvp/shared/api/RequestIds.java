package com.rmf.rdvp.shared.api;

import java.util.UUID;
import java.util.regex.Pattern;

import jakarta.servlet.http.HttpServletRequest;

public final class RequestIds {

    public static final String HEADER_NAME = "X-Request-Id";
    private static final Pattern REQUEST_ID_PATTERN = Pattern.compile("^[A-Za-z0-9._:-]{1,128}$");

    private RequestIds() {
    }

    public static String resolve(HttpServletRequest request) {
        String requestId = request.getHeader(HEADER_NAME);
        if (requestId == null || !REQUEST_ID_PATTERN.matcher(requestId.trim()).matches()) {
            return UUID.randomUUID().toString();
        }

        return requestId.trim();
    }
}
