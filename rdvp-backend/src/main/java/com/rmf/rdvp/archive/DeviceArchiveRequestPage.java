package com.rmf.rdvp.archive;

import java.util.List;

public record DeviceArchiveRequestPage(
        List<DeviceArchiveRequest> items,
        long total) {
}
