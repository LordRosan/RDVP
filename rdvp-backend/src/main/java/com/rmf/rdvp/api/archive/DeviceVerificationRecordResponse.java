package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;

import com.rmf.rdvp.archive.DeviceVerificationRecord;

public record DeviceVerificationRecordResponse(
        String id,
        String deviceId,
        String operatorId,
        String result,
        String description,
        String remark,
        String verifiedAt,
        String createdAt) {

    public static DeviceVerificationRecordResponse from(DeviceVerificationRecord record) {
        return new DeviceVerificationRecordResponse(
                record.id(),
                record.deviceId(),
                record.operatorId(),
                record.result().name(),
                record.description(),
                record.remark(),
                toIsoString(record.verifiedAt()),
                toIsoString(record.createdAt()));
    }

    private static String toIsoString(OffsetDateTime value) {
        if (value == null) {
            return null;
        }

        return value.toInstant().toString();
    }
}
