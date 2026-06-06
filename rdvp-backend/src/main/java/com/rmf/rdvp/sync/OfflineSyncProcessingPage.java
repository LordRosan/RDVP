package com.rmf.rdvp.sync;

import java.util.List;

public record OfflineSyncProcessingPage(
        List<OfflineSyncProcessingRecord> items,
        long total) {
}
