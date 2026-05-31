package com.rmf.rdvp.api.common;

public record ApiError(
        String code,
        String message,
        Object details) {
}
