package com.rmf.rdvp.api.operations;

import java.util.List;

import com.rmf.rdvp.operations.OperationsReviewRequestPage;

public record OperationsReviewRequestListResponse(
        List<OperationsReviewRequestResponse> items,
        long total) {

    public static OperationsReviewRequestListResponse from(OperationsReviewRequestPage page) {
        return new OperationsReviewRequestListResponse(
                page.items().stream().map(OperationsReviewRequestResponse::from).toList(),
                page.total());
    }
}
