package com.rmf.rdvp.api.archive;

import java.util.List;

import com.rmf.rdvp.archive.DeviceChangeRequestPage;

public record DeviceChangeReviewListResponse(
        List<DeviceChangeReviewResponse> items,
        long total) {

    public static DeviceChangeReviewListResponse from(DeviceChangeRequestPage page) {
        return new DeviceChangeReviewListResponse(
                page.items().stream().map(DeviceChangeReviewResponse::from).toList(),
                page.total());
    }
}
