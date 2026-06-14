package com.rmf.rdvp.records;

import org.springframework.stereotype.Service;

@Service
public class RecordCenterService {

    private static final int MAX_PAGE_SIZE = 100;

    private final RecordCenterRepository recordCenterRepository;

    public RecordCenterService(RecordCenterRepository recordCenterRepository) {
        this.recordCenterRepository = recordCenterRepository;
    }

    public RecordListResponse queryRecords(String category, String type, String keyword, int page, int pageSize) {
        int limit = Math.min(pageSize > 0 ? pageSize : 20, MAX_PAGE_SIZE);
        int offset = Math.max(page - 1, 0) * limit;

        return switch (category.toUpperCase()) {
            case "ARCHIVE" -> recordCenterRepository.queryArchiveRecords(type, keyword, limit, offset);
            case "REVIEW" -> recordCenterRepository.queryReviewRecords(type, keyword, limit, offset);
            case "OPERATIONS" -> recordCenterRepository.queryOperationsRecords(type, keyword, limit, offset);
            default -> throw new IllegalArgumentException("Invalid category: " + category);
        };
    }
}
