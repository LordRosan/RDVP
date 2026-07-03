package com.rmf.rdvp.archive;

import java.util.List;

public record ArchiveRequestPage(
        List<ArchiveRequest> items,
        long total) {
}
