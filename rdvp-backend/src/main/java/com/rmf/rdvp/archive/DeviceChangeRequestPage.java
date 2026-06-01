package com.rmf.rdvp.archive;

import java.util.List;

public record DeviceChangeRequestPage(
        List<DeviceChangeRequest> items,
        long total) {
}
