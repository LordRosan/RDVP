package com.rmf.rdvp.records;

import java.util.Comparator;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import com.rmf.rdvp.archive.DeviceArchiveRequest;
import com.rmf.rdvp.archive.DeviceArchiveRequestQuery;
import com.rmf.rdvp.archive.DeviceArchiveRequestRepository;
import com.rmf.rdvp.operations.OperationsReviewRequest;
import com.rmf.rdvp.operations.OperationsReviewRequestPage;
import com.rmf.rdvp.operations.OperationsRepository;

@Repository
@Profile("test")
public class InMemoryRecordQueryRepository implements RecordQueryRepository {

    private final DeviceArchiveRequestRepository archiveRequestRepository;
    private final OperationsRepository operationsRepository;

    public InMemoryRecordQueryRepository(
            DeviceArchiveRequestRepository archiveRequestRepository,
            OperationsRepository operationsRepository) {
        this.archiveRequestRepository = archiveRequestRepository;
        this.operationsRepository = operationsRepository;
    }

    @Override
    public RecordListResponse queryArchiveRecords(String type, String keyword, int limit, int offset) {
        return empty();
    }

    @Override
    public RecordListResponse queryReviewRecords(String type, String keyword, int limit, int offset) {
        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase();
        var archiveRequests = archiveRequestRepository.list(new DeviceArchiveRequestQuery(
                        null,
                        null,
                        null,
                        type,
                        1,
                        Integer.MAX_VALUE))
                .items()
                .stream()
                .filter(item -> item.reviewedAt() != null)
                .filter(item -> normalizedKeyword.isBlank()
                        || contains(item.deviceCode(), normalizedKeyword)
                        || contains(item.deviceName(), normalizedKeyword))
                .map(this::toArchiveReviewRecord)
                .toList();

        OperationsReviewRequestPage operationPage = operationsRepository.listOperationsReviewRequests(
                null,
                null,
                keyword,
                Integer.MAX_VALUE,
                0);
        var operationRequests = operationPage.items()
                .stream()
                .filter(item -> item.reviewedAt() != null)
                .filter(item -> matchesOperationsReviewType(item.type().name(), type))
                .map(this::toOperationsReviewRecord)
                .toList();

        List<RecordItemResponse> items = java.util.stream.Stream.concat(archiveRequests.stream(), operationRequests.stream())
                .sorted(Comparator.comparing(RecordItemResponse::occurredAt).reversed())
                .toList();
        List<RecordItemResponse> page = items.stream()
                .skip(offset)
                .limit(limit)
                .toList();
        return new RecordListResponse(page, items.size());
    }

    @Override
    public RecordListResponse queryOperationRecords(String type, String keyword, int limit, int offset) {
        return empty();
    }

    private RecordListResponse empty() {
        return new RecordListResponse(List.of(), 0);
    }

    private RecordItemResponse toArchiveReviewRecord(DeviceArchiveRequest request) {
        return new RecordItemResponse(
                "REVIEW",
                request.type().name(),
                request.deviceCode(),
                request.id(),
                firstPresent(request.reviewerId(), request.applicantName(), request.applicantId()),
                request.reviewedAt(),
                request.status().name(),
                request.reviewComment());
    }

    private RecordItemResponse toOperationsReviewRecord(OperationsReviewRequest request) {
        return new RecordItemResponse(
                "REVIEW",
                request.type().name(),
                request.deviceCode(),
                request.targetNo(),
                firstPresent(request.reviewOperatorId(), request.operatorName(), request.operatorId()),
                request.reviewedAt(),
                request.status().name(),
                request.reviewComment());
    }

    private boolean contains(String value, String keyword) {
        return value != null && value.toLowerCase().contains(keyword);
    }

    private boolean matchesOperationsReviewType(String recordType, String filterType) {
        if (filterType == null || filterType.isBlank()) {
            return true;
        }
        if (recordType.equalsIgnoreCase(filterType)) {
            return true;
        }
        return "REINSPECTION_REPORT".equalsIgnoreCase(recordType)
                && "REINSPECTION_RECORD".equalsIgnoreCase(filterType);
    }

    private String firstPresent(String first, String second, String third) {
        if (first != null && !first.isBlank()) {
            return first;
        }
        if (second != null && !second.isBlank()) {
            return second;
        }
        return third == null || third.isBlank() ? "-" : third;
    }
}
