package com.rmf.rdvp.operations;

import java.util.List;

public record OperationReviewRequestPage(
        List<OperationReviewRequest> items,
        long total) {
}
