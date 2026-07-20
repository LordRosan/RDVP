package com.rmf.rdvp.archive.api;

import java.util.List;
import java.util.Map;

import com.rmf.rdvp.archive.ArchiveImage;
import com.rmf.rdvp.archive.ArchiveRequestPage;

public record ArchiveReviewListResponse(
        List<ArchiveReviewResponse> items,
        long total) {

    public static ArchiveReviewListResponse from(ArchiveRequestPage page) {
        return from(page, Map.of());
    }

    public static ArchiveReviewListResponse from(
            ArchiveRequestPage page,
            Map<String, List<ArchiveImage>> imageChangesByRequestId) {
        return new ArchiveReviewListResponse(
                page.items().stream()
                        .map(request -> {
                            boolean imagesChanged = imageChangesByRequestId.containsKey(request.id());
                            List<ArchiveImage> images = imageChangesByRequestId.getOrDefault(request.id(), List.of());
                            return ArchiveReviewResponse.from(request, images, imagesChanged);
                        })
                        .toList(),
                page.total());
    }
}
