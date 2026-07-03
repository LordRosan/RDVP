package com.rmf.rdvp.shared.error;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    BAD_REQUEST("BAD_REQUEST", HttpStatus.BAD_REQUEST, "Request parameters are invalid."),
    UNAUTHORIZED("UNAUTHORIZED", HttpStatus.UNAUTHORIZED, "Authentication is required."),
    ACCOUNT_INCORRECT("ACCOUNT_INCORRECT", HttpStatus.UNAUTHORIZED, "Account is incorrect."),
    PASSWORD_INCORRECT("PASSWORD_INCORRECT", HttpStatus.UNAUTHORIZED, "Password is incorrect."),
    PASSWORD_VERIFICATION_LOCKED(
            "PASSWORD_VERIFICATION_LOCKED",
            HttpStatus.TOO_MANY_REQUESTS,
            "Password verification is temporarily locked."),
    SENSITIVE_OPERATION_VERIFICATION_REQUIRED(
            "SENSITIVE_OPERATION_VERIFICATION_REQUIRED",
            HttpStatus.FORBIDDEN,
            "Recent password verification is required for this sensitive operation."),
    FORBIDDEN("FORBIDDEN", HttpStatus.FORBIDDEN, "Permission is denied."),
    RATE_LIMITED("RATE_LIMITED", HttpStatus.TOO_MANY_REQUESTS, "Too many attempts. Please retry later."),
    NOT_FOUND("NOT_FOUND", HttpStatus.NOT_FOUND, "Resource was not found."),
    CONFLICT("CONFLICT", HttpStatus.CONFLICT, "Resource state conflict."),
    VALIDATION_FAILED("VALIDATION_FAILED", HttpStatus.UNPROCESSABLE_CONTENT, "Request validation failed."),
    DEVICE_NOT_FOUND("DEVICE_NOT_FOUND", HttpStatus.NOT_FOUND, "Device not found."),
    DEVICE_CODE_DUPLICATED("DEVICE_CODE_DUPLICATED", HttpStatus.CONFLICT, "Device code already exists."),
    DEVICE_CODE_INVALID("DEVICE_CODE_INVALID", HttpStatus.BAD_REQUEST, "Device code format is invalid."),
    ARCHIVE_INVALID("ARCHIVE_INVALID", HttpStatus.UNPROCESSABLE_CONTENT, "Device archive is invalid."),
    ARCHIVE_DELETE_BLOCKED(
            "ARCHIVE_DELETE_BLOCKED",
            HttpStatus.CONFLICT,
            "Device archive cannot be deleted in its current state."),
    QR_CODE_INVALID("QR_CODE_INVALID", HttpStatus.BAD_REQUEST, "QR code content is invalid."),
    QR_CODE_EXPIRED("QR_CODE_EXPIRED", HttpStatus.BAD_REQUEST, "QR code is expired."),
    QR_CODE_SIGNATURE_INVALID("QR_CODE_SIGNATURE_INVALID", HttpStatus.BAD_REQUEST, "QR code signature verification failed."),
    ARCHIVE_REQUEST_INVALID(
            "ARCHIVE_REQUEST_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Device archive request is invalid."),
    ARCHIVE_REQUEST_LOCKED("ARCHIVE_REQUEST_LOCKED", HttpStatus.CONFLICT, "Device archive has a pending archive request."),
    ARCHIVE_REQUEST_FROZEN("ARCHIVE_REQUEST_FROZEN", HttpStatus.CONFLICT, "Device archive request is frozen."),
    ARCHIVE_REQUEST_NOT_FOUND("ARCHIVE_REQUEST_NOT_FOUND", HttpStatus.NOT_FOUND, "Device archive request not found."),
    ARCHIVE_REQUEST_ALREADY_REVIEWED(
            "ARCHIVE_REQUEST_ALREADY_REVIEWED",
            HttpStatus.CONFLICT,
            "Device archive request has already been reviewed."),
    DEVICE_VERIFICATION_INVALID(
            "DEVICE_VERIFICATION_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Device verification record is invalid."),
    FAULT_REPORT_INVALID("FAULT_REPORT_INVALID", HttpStatus.UNPROCESSABLE_CONTENT, "Fault report is invalid."),
    FAULT_REPORT_NOT_FOUND("FAULT_REPORT_NOT_FOUND", HttpStatus.NOT_FOUND, "Fault report not found."),
    DEVICE_ACTIVE_FAULT_EXISTS(
            "DEVICE_ACTIVE_FAULT_EXISTS",
            HttpStatus.CONFLICT,
            "Device already has an active fault workflow."),
    FAULT_ALREADY_ACCEPTED("FAULT_ALREADY_ACCEPTED", HttpStatus.CONFLICT, "Fault has already been accepted."),
    REPAIR_REPORT_INVALID("REPAIR_REPORT_INVALID", HttpStatus.UNPROCESSABLE_CONTENT, "Repair report is invalid."),
    REPAIR_REPORT_NOT_FOUND("REPAIR_REPORT_NOT_FOUND", HttpStatus.NOT_FOUND, "Repair report not found."),
    REPAIR_TASK_NOT_FOUND("REPAIR_TASK_NOT_FOUND", HttpStatus.NOT_FOUND, "Repair task not found."),
    REPAIR_TASK_STATUS_INVALID(
            "REPAIR_TASK_STATUS_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Repair task status does not allow this operation."),
    REPAIR_TASK_RADIUS_INVALID(
            "REPAIR_TASK_RADIUS_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Repair task radius is invalid."),
    REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD(
            "REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Repair task radius exceeds current workload policy."),
    REPAIRER_BUSY("REPAIRER_BUSY", HttpStatus.CONFLICT, "Repairer is too busy to accept more tasks."),
    REINSPECTION_REPORT_INVALID(
            "REINSPECTION_REPORT_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Reinspection report is invalid."),
    REINSPECTION_REQUIRED(
            "REINSPECTION_REQUIRED",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Current fault is not pending reinspection."),
    OPERATIONS_REVIEW_REQUEST_NOT_FOUND(
            "OPERATIONS_REVIEW_REQUEST_NOT_FOUND",
            HttpStatus.NOT_FOUND,
            "operations review request not found."),
    OPERATIONS_REVIEW_REQUEST_ALREADY_REVIEWED(
            "OPERATIONS_REVIEW_REQUEST_ALREADY_REVIEWED",
            HttpStatus.CONFLICT,
            "operations review request has already been reviewed."),
    OPERATIONS_REVIEW_REQUEST_INVALID(
            "OPERATIONS_REVIEW_REQUEST_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "operations review request is invalid."),
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
