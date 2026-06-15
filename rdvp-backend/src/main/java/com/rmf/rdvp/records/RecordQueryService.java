package com.rmf.rdvp.records;

import org.springframework.stereotype.Service;

@Service
public class RecordQueryService {

    private static final int MAX_PAGE_SIZE = 100;

    private final RecordQueryRepository recordQueryRepository;

    public RecordQueryService(RecordQueryRepository recordQueryRepository) {
        this.recordQueryRepository = recordQueryRepository;
    }

    public RecordListResponse queryRecords(String category, String type, String keyword, int page, int pageSize) {
        int limit = Math.min(pageSize > 0 ? pageSize : 20, MAX_PAGE_SIZE);
        int offset = Math.max(page - 1, 0) * limit;

        return switch (category.toUpperCase()) {
            case "ARCHIVE" -> recordQueryRepository.queryArchiveRecords(type, keyword, limit, offset);
            case "REVIEW" -> recordQueryRepository.queryReviewRecords(type, keyword, limit, offset);
            case "OPERATIONS" -> recordQueryRepository.queryOperationRecords(type, keyword, limit, offset);
            default -> throw new IllegalArgumentException("Invalid category: " + category);
        };
    }
}
