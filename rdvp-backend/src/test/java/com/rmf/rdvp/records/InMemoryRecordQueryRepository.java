package com.rmf.rdvp.records;

import java.util.Comparator;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogQuery;
import com.rmf.rdvp.audit.AuditLogRecord;
import com.rmf.rdvp.audit.AuditLogRepository;
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
    private final AuditLogRepository auditLogRepository;

    public InMemoryRecordQueryRepository(
            DeviceArchiveRequestRepository archiveRequestRepository,
            OperationsRepository operationsRepository,
            AuditLogRepository auditLogRepository) {
        this.archiveRequestRepository = archiveRequestRepository;
        this.operationsRepository = operationsRepository;
        this.auditLogRepository = auditLogRepository;
    }

    @Override
    public RecordListResponse queryArchiveRecords(
            String type,
            String keyword,
            RecordQueryTimeRange timeRange,
            int limit,
            int offset) {
        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase();
        var requestRecords = archiveRequestRepository.list(new DeviceArchiveRequestQuery(
                        null,
                        null,
                        null,
                        isAuditArchiveType(type) ? "NO_MATCH" : type,
                        1,
                        Integer.MAX_VALUE))
                .items()
                .stream()
                .filter(item -> matchesTimeRange(item.initiatedAt(), timeRange))
                .filter(item -> normalizedKeyword.isBlank()
                        || contains(item.deviceCode(), normalizedKeyword)
                        || contains(item.deviceName(), normalizedKeyword)
                        || contains(item.applicantName(), normalizedKeyword)
                        || contains(item.applicantId(), normalizedKeyword))
                .map(this::toArchiveRecord)
                .toList();

        var auditRecords = shouldIncludeArchiveAuditRecords(type)
                ? auditLogRepository.list(new AuditLogQuery(
                                parseArchiveAuditAction(type),
                                keyword,
                                1,
                                Integer.MAX_VALUE))
                        .items()
                        .stream()
                        .filter(item -> isArchiveAuditAction(item.action()))
                        .filter(item -> matchesTimeRange(item.occurredAt(), timeRange))
                        .map(this::toArchiveAuditRecord)
                        .toList()
                : List.<RecordItemResponse>of();

        return pageRecords(java.util.stream.Stream.concat(requestRecords.stream(), auditRecords.stream()).toList(), limit, offset);
    }

    @Override
    public RecordListResponse queryReviewRecords(
            String type,
            String keyword,
            RecordQueryTimeRange timeRange,
            int limit,
            int offset) {
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
                .filter(item -> matchesTimeRange(item.reviewedAt(), timeRange))
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
                .filter(item -> matchesTimeRange(item.reviewedAt(), timeRange))
                .filter(item -> matchesOperationsReviewType(item.type().name(), type))
                .map(this::toOperationsReviewRecord)
                .toList();

        return pageRecords(java.util.stream.Stream.concat(archiveRequests.stream(), operationRequests.stream()).toList(), limit, offset);
    }

    @Override
    public RecordListResponse queryOperationsRecords(
            String type,
            String keyword,
            RecordQueryTimeRange timeRange,
            int limit,
            int offset) {
        return empty();
    }

    private RecordListResponse empty() {
        return new RecordListResponse(List.of(), 0);
    }

    private RecordItemResponse toArchiveRecord(DeviceArchiveRequest request) {
        return new RecordItemResponse(
                "ARCHIVE",
                request.type().name(),
                request.deviceCode(),
                request.id(),
                firstPresent(request.applicantName(), request.applicantId(), null),
                request.initiatedAt(),
                request.status().name(),
                request.reason());
    }

    private RecordItemResponse toArchiveAuditRecord(AuditLogRecord record) {
        return new RecordItemResponse(
                "ARCHIVE",
                record.action().name(),
                firstPresent(record.targetNo(), record.targetId(), "-"),
                record.id(),
                firstPresent(record.actorName(), record.actorId(), null),
                record.occurredAt(),
                record.status().name(),
                record.description());
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

    private boolean matchesTimeRange(java.time.OffsetDateTime value, RecordQueryTimeRange timeRange) {
        return timeRange == null || timeRange.contains(value);
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

    private RecordListResponse pageRecords(List<RecordItemResponse> records, int limit, int offset) {
        List<RecordItemResponse> items = records.stream()
                .sorted(Comparator.comparing(RecordItemResponse::occurredAt).reversed())
                .toList();
        List<RecordItemResponse> page = items.stream()
                .skip(offset)
                .limit(limit)
                .toList();
        return new RecordListResponse(page, items.size());
    }

    private AuditAction parseArchiveAuditAction(String type) {
        if (type == null || type.isBlank()) {
            return null;
        }

        if ("DEVICE_ARCHIVE_QUERY".equalsIgnoreCase(type)) {
            return AuditAction.DEVICE_ARCHIVE_QUERY;
        }

        if ("DEVICE_ARCHIVE_EXPORT".equalsIgnoreCase(type)) {
            return AuditAction.DEVICE_ARCHIVE_EXPORT;
        }

        return null;
    }

    private boolean isAuditArchiveType(String type) {
        return "DEVICE_ARCHIVE_QUERY".equalsIgnoreCase(type)
                || "DEVICE_ARCHIVE_EXPORT".equalsIgnoreCase(type);
    }

    private boolean shouldIncludeArchiveAuditRecords(String type) {
        return type == null || type.isBlank() || isAuditArchiveType(type);
    }

    private boolean isArchiveAuditAction(AuditAction action) {
        return action == AuditAction.DEVICE_ARCHIVE_QUERY
                || action == AuditAction.DEVICE_ARCHIVE_EXPORT;
    }
}
