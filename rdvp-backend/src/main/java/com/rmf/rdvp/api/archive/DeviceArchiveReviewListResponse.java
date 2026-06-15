package com.rmf.rdvp.api.archive;

import java.util.List;

import com.rmf.rdvp.archive.DeviceArchiveChangeRequestPage;

public record DeviceArchiveReviewListResponse(
        List<DeviceArchiveReviewResponse> items,
        long total) {

    public static DeviceArchiveReviewListResponse from(DeviceArchiveChangeRequestPage page) {
        return new DeviceArchiveReviewListResponse(
                page.items().stream().map(DeviceArchiveReviewResponse::from).toList(),
                page.total());
    }
}
