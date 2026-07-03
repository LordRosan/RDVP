package com.rmf.rdvp.archive.api;

import java.util.List;

import com.rmf.rdvp.archive.DeviceArchiveRequestPage;

public record DeviceArchiveReviewListResponse(
        List<DeviceArchiveReviewResponse> items,
        long total) {

    public static DeviceArchiveReviewListResponse from(DeviceArchiveRequestPage page) {
        return new DeviceArchiveReviewListResponse(
                page.items().stream().map(DeviceArchiveReviewResponse::from).toList(),
                page.total());
    }
}
