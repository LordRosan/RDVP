package com.rmf.rdvp.domain.common;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    BAD_REQUEST("BAD_REQUEST", HttpStatus.BAD_REQUEST, "Request parameters are invalid."),
    UNAUTHORIZED("UNAUTHORIZED", HttpStatus.UNAUTHORIZED, "Authentication is required."),
    INVALID_CREDENTIALS("INVALID_CREDENTIALS", HttpStatus.UNAUTHORIZED, "Username or password is incorrect."),
    FORBIDDEN("FORBIDDEN", HttpStatus.FORBIDDEN, "Permission is denied."),
    NOT_FOUND("NOT_FOUND", HttpStatus.NOT_FOUND, "Resource was not found."),
    CONFLICT("CONFLICT", HttpStatus.CONFLICT, "Resource state conflict."),
    VALIDATION_FAILED("VALIDATION_FAILED", HttpStatus.UNPROCESSABLE_CONTENT, "Request validation failed."),
    DEVICE_NOT_FOUND("DEVICE_NOT_FOUND", HttpStatus.NOT_FOUND, "Device not found."),
    DEVICE_CODE_INVALID("DEVICE_CODE_INVALID", HttpStatus.BAD_REQUEST, "Device code format is invalid."),
    QR_CODE_INVALID("QR_CODE_INVALID", HttpStatus.BAD_REQUEST, "QR code content is invalid."),
    QR_CODE_EXPIRED("QR_CODE_EXPIRED", HttpStatus.BAD_REQUEST, "QR code is expired."),
    QR_CODE_SIGNATURE_INVALID("QR_CODE_SIGNATURE_INVALID", HttpStatus.BAD_REQUEST, "QR code signature verification failed."),
    DEVICE_CHANGE_REQUEST_INVALID(
            "DEVICE_CHANGE_REQUEST_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Device change request is invalid."),
    DEVICE_CHANGE_LOCKED("DEVICE_CHANGE_LOCKED", HttpStatus.CONFLICT, "Device has a pending change request."),
    DEVICE_CHANGE_FROZEN("DEVICE_CHANGE_FROZEN", HttpStatus.CONFLICT, "Device archive change is frozen."),
    CHANGE_REQUEST_NOT_FOUND("CHANGE_REQUEST_NOT_FOUND", HttpStatus.NOT_FOUND, "Device change request not found."),
    CHANGE_REQUEST_ALREADY_REVIEWED(
            "CHANGE_REQUEST_ALREADY_REVIEWED",
            HttpStatus.CONFLICT,
            "Device change request has already been reviewed."),
    INTERNAL_ERROR("INTERNAL_ERROR", HttpStatus.INTERNAL_SERVER_ERROR, "Internal server error.");

    private final String code;
    private final HttpStatus status;
    private final String defaultMessage;

    ErrorCode(String code, HttpStatus status, String defaultMessage) {
        this.code = code;
        this.status = status;
        this.defaultMessage = defaultMessage;
    }

    public String code() {
        return code;
    }

    public HttpStatus status() {
        return status;
    }

    public String defaultMessage() {
        return defaultMessage;
    }
}
