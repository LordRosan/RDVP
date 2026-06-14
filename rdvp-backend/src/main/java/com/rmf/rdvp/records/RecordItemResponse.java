package com.rmf.rdvp.records;

import java.time.OffsetDateTime;

public record RecordItemResponse(
        String recordCategory,
        String recordType,
        String deviceCode,
        String taskNo,
        String operatorName,
        OffsetDateTime occurredAt,
        String businessStatus,
        String description) {
}
