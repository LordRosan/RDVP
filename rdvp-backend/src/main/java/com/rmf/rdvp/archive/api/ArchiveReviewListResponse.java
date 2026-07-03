package com.rmf.rdvp.archive.api;

import java.util.List;

import com.rmf.rdvp.archive.ArchiveRequestPage;

public record ArchiveReviewListResponse(
        List<ArchiveReviewResponse> items,
        long total) {

    public static ArchiveReviewListResponse from(ArchiveRequestPage page) {
        return new ArchiveReviewListResponse(
                page.items().stream().map(ArchiveReviewResponse::from).toList(),
                page.total());
    }
}
