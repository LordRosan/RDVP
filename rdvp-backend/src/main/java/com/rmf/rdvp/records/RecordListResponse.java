package com.rmf.rdvp.records;

import java.util.List;

public record RecordListResponse(
        List<RecordItemResponse> items,
        long total) {
}
