package com.rmf.rdvp.sync;

import java.time.OffsetDateTime;

public record OfflineSyncRecordInput(
        String clientRecordId,
        OfflineSyncRecordType recordType,
        Object payload,
        OffsetDateTime createdOfflineAt) {
}
