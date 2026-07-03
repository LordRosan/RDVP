package com.rmf.rdvp.shared.api;

public record ApiError(
        String code,
        String message,
        Object details) {
}
