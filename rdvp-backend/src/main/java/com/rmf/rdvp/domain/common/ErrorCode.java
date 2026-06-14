package com.rmf.rdvp.domain.common;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    BAD_REQUEST("BAD_REQUEST", HttpStatus.BAD_REQUEST, "Request parameters are invalid."),
    UNAUTHORIZED("UNAUTHORIZED", HttpStatus.UNAUTHORIZED, "Authentication is required."),
    INVALID_CREDENTIALS("INVALID_CREDENTIALS", HttpStatus.UNAUTHORIZED, "Username or password is incorrect."),
    PASSWORD_VERIFICATION_LOCKED(
            "PASSWORD_VERIFICATION_LOCKED",
            HttpStatus.TOO_MANY_REQUESTS,
            "Password verification is temporarily locked."),
    SENSITIVE_OPERATION_VERIFICATION_REQUIRED(
            "SENSITIVE_OPERATION_VERIFICATION_REQUIRED",
            HttpStatus.FORBIDDEN,
            "Recent password verification is required for this sensitive operation."),
    FORBIDDEN("FORBIDDEN", HttpStatus.FORBIDDEN, "Permission is denied."),
    NOT_FOUND("NOT_FOUND", HttpStatus.NOT_FOUND, "Resource was not found."),
    CONFLICT("CONFLICT", HttpStatus.CONFLICT, "Resource state conflict."),
    VALIDATION_FAILED("VALIDATION_FAILED", HttpStatus.UNPROCESSABLE_CONTENT, "Request validation failed."),
    DEVICE_NOT_FOUND("DEVICE_NOT_FOUND", HttpStatus.NOT_FOUND, "Device not found."),
    DEVICE_CODE_DUPLICATED("DEVICE_CODE_DUPLICATED", HttpStatus.CONFLICT, "Device code already exists."),
    DEVICE_CODE_INVALID("DEVICE_CODE_INVALID", HttpStatus.BAD_REQUEST, "Device code format is invalid."),
    DEVICE_ARCHIVE_INVALID("DEVICE_ARCHIVE_INVALID", HttpStatus.UNPROCESSABLE_CONTENT, "Device archive is invalid."),
    DEVICE_ARCHIVE_DELETE_BLOCKED(
            "DEVICE_ARCHIVE_DELETE_BLOCKED",
            HttpStatus.CONFLICT,
            "Device archive cannot be deleted in its current state."),
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
    REINSPECTION_RECORD_INVALID(
            "REINSPECTION_RECORD_INVALID",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Reinspection record is invalid."),
    REINSPECTION_REQUIRED(
            "REINSPECTION_REQUIRED",
            HttpStatus.UNPROCESSABLE_CONTENT,
            "Current fault is not pending reinspection."),
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
