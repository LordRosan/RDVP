package com.rmf.rdvp.log;

import java.time.OffsetDateTime;

public record LogItem(
        String logCategory,
        String logType,
        String deviceCode,
        String taskNo,
        String operatorName,
        OffsetDateTime occurredAt,
        String businessStatus,
        String description) {
}
