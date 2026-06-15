package com.rmf.rdvp.archive;

import java.util.List;

public record DeviceArchiveChangeRequestPage(
        List<DeviceArchiveChangeRequest> items,
        long total) {
}
