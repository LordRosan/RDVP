package com.rmf.rdvp.records;

import java.time.OffsetDateTime;

public record RecordQueryTimeRange(
        OffsetDateTime startInclusive,
        OffsetDateTime endExclusive) {

    public boolean contains(OffsetDateTime value) {
        if (value == null) {
            return false;
        }

        if (startInclusive != null && value.isBefore(startInclusive)) {
            return false;
        }

        return endExclusive == null || value.isBefore(endExclusive);
    }
}
