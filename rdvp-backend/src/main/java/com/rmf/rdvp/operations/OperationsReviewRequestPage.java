package com.rmf.rdvp.operations;

import java.util.List;

public record OperationsReviewRequestPage(
        List<OperationsReviewRequest> items,
        long total) {
}
