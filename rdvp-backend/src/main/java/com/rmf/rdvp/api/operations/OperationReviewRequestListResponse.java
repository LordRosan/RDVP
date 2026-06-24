package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.OperationReviewRequestPage;

public record OperationReviewRequestListResponse(
        List<OperationReviewRequestResponse> items,
        long total) {

    public static OperationReviewRequestListResponse from(OperationReviewRequestPage page) {
        return new OperationReviewRequestListResponse(
                page.items().stream().map(OperationReviewRequestResponse::from).toList(),
                page.total());
    }
}
