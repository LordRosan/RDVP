package com.rmf.rdvp.shared.api;

import java.time.Instant;

public record ApiResponse<T>(
        boolean success,
        T data,
        ApiError error,
        String requestId,
        String timestamp) {

    public static <T> ApiResponse<T> success(T data, String requestId) {
        return new ApiResponse<>(true, data, null, requestId, Instant.now().toString());
    }

    public static ApiResponse<Void> failure(ApiError error, String requestId) {
        return new ApiResponse<>(false, null, error, requestId, Instant.now().toString());
    }
}
