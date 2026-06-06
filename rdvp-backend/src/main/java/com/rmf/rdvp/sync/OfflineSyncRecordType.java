package com.rmf.rdvp.sync;

import java.util.Locale;

import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;

public enum OfflineSyncRecordType {
    FAULT_REPORT_CREATE,
    DEVICE_VERIFICATION_CREATE,
    DEVICE_VERIFICATION_FAULT_REPORT_CREATE,
    DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE,
    DEVICE_ARCHIVE_CREATE_REQUEST_CREATE,
    DEVICE_ARCHIVE_DELETE_REQUEST_CREATE;

    public static OfflineSyncRecordType parse(String value) {
        String normalized = value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "FAULT_REPORT", "FAULT_REPORT_CREATE" -> FAULT_REPORT_CREATE;
            case "DEVICE_VERIFICATION", "DEVICE_VERIFICATION_CREATE" -> DEVICE_VERIFICATION_CREATE;
            case "DEVICE_VERIFICATION_FAULT_REPORT", "DEVICE_VERIFICATION_FAULT_REPORT_CREATE" ->
                    DEVICE_VERIFICATION_FAULT_REPORT_CREATE;
            case "DEVICE_ARCHIVE_UPDATE_REQUEST", "DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE" ->
                    DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE;
            case "DEVICE_ARCHIVE_CREATE_REQUEST", "DEVICE_ARCHIVE_CREATE_REQUEST_CREATE" ->
                    DEVICE_ARCHIVE_CREATE_REQUEST_CREATE;
            case "DEVICE_ARCHIVE_DELETE_REQUEST", "DEVICE_ARCHIVE_DELETE_REQUEST_CREATE" ->
                    DEVICE_ARCHIVE_DELETE_REQUEST_CREATE;
            default -> throw new BusinessException(ErrorCode.OFFLINE_SYNC_RECORD_INVALID, "recordType is invalid.");
        };
    }
}
