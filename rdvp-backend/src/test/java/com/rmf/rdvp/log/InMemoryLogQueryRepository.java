package com.rmf.rdvp.log;

import java.util.Comparator;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryQuery;
import com.rmf.rdvp.log.LogEntry;
import com.rmf.rdvp.log.LogEntryRepository;
import com.rmf.rdvp.archive.ArchiveRequest;
import com.rmf.rdvp.archive.ArchiveRequestQuery;
import com.rmf.rdvp.archive.ArchiveRequestRepository;
import com.rmf.rdvp.operations.OperationsReviewRequest;
import com.rmf.rdvp.operations.OperationsReviewRequestPage;
import com.rmf.rdvp.operations.OperationsRepository;

@Repository
@Profile("test")
public class InMemoryLogQueryRepository implements LogQueryRepository {

    private final ArchiveRequestRepository archiveRequestRepository;
    private final OperationsRepository operationsRepository;
    private final LogEntryRepository logEntryRepository;

    public InMemoryLogQueryRepository(
            ArchiveRequestRepository archiveRequestRepository,
            OperationsRepository operationsRepository,
            LogEntryRepository logEntryRepository) {
        this.archiveRequestRepository = archiveRequestRepository;
        this.operationsRepository = operationsRepository;
        this.logEntryRepository = logEntryRepository;
    }

    @Override
    public LogList queryArchiveLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase();
        var requestLogs = archiveRequestRepository.list(new ArchiveRequestQuery(
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
                .map(this::toArchiveLog)
                .toList();

        var logEntryLogs = shouldIncludeArchiveLogEntries(type)
                ? logEntryRepository.list(new LogEntryQuery(
                                parseArchiveLogAction(type),
                                keyword,
                                1,
                                Integer.MAX_VALUE))
                        .items()
                        .stream()
                        .filter(item -> isArchiveLogAction(item.action()))
                        .filter(item -> matchesTimeRange(item.occurredAt(), timeRange))
                        .map(this::toArchiveLogEntry)
                        .toList()
                : List.<LogItem>of();

        return pageLogs(java.util.stream.Stream.concat(requestLogs.stream(), logEntryLogs.stream()).toList(), limit, offset);
    }

    @Override
    public LogList queryArchiveReviewLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase();
        var archiveRequests = archiveRequestRepository.list(new ArchiveRequestQuery(
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
                .map(this::toArchiveReviewLog)
                .toList();

        return pageLogs(archiveRequests, limit, offset);
    }

    @Override
    public LogList queryOperationsReviewLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
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
                .map(this::toOperationsReviewLog)
                .toList();

        return pageLogs(operationRequests, limit, offset);
    }

    @Override
    public LogList queryOperationsLogs(
            String type,
            String keyword,
            LogQueryTimeRange timeRange,
            int limit,
            int offset) {
        return empty();
    }

    private LogList empty() {
        return new LogList(List.of(), 0);
    }

    private LogItem toArchiveLog(ArchiveRequest request) {
        return new LogItem(
                "ARCHIVE_OPERATION",
                request.type().name(),
                request.deviceCode(),
                request.id(),
                firstPresent(request.applicantName(), request.applicantId(), null),
                request.initiatedAt(),
                request.status().name(),
                request.reason());
    }

    private LogItem toArchiveLogEntry(LogEntry record) {
        return new LogItem(
                "ARCHIVE_OPERATION",
                record.action().name(),
                firstPresent(record.targetNo(), record.targetId(), "-"),
                record.id(),
                firstPresent(record.actorName(), record.actorId(), null),
                record.occurredAt(),
                record.status().name(),
                record.description());
    }

    private LogItem toArchiveReviewLog(ArchiveRequest request) {
        return new LogItem(
                "ARCHIVE_REVIEW",
                request.type().name(),
                request.deviceCode(),
                request.id(),
                firstPresent(request.reviewerId(), request.applicantName(), request.applicantId()),
                request.reviewedAt(),
                request.status().name(),
                request.reviewComment());
    }

    private LogItem toOperationsReviewLog(OperationsReviewRequest request) {
        return new LogItem(
                "OPERATIONS_REVIEW",
                request.type().name(),
                request.deviceCode(),
                request.targetNo(),
                firstPresent(request.reviewerId(), request.operatorName(), request.operatorId()),
                request.reviewedAt(),
                request.status().name(),
                request.reviewComment());
    }

    private boolean contains(String value, String keyword) {
        return value != null && value.toLowerCase().contains(keyword);
    }

    private boolean matchesTimeRange(java.time.OffsetDateTime value, LogQueryTimeRange timeRange) {
        return timeRange == null || timeRange.contains(value);
    }

    private boolean matchesOperationsReviewType(String logType, String filterType) {
        if (filterType == null || filterType.isBlank()) {
            return true;
        }
        if (logType.equalsIgnoreCase(filterType)) {
            return true;
        }
        return "REINSPECTION_REPORT".equalsIgnoreCase(logType)
                && "REINSPECTION_REPORT".equalsIgnoreCase(filterType);
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

    private LogList pageLogs(List<LogItem> logs, int limit, int offset) {
        List<LogItem> items = logs.stream()
                .sorted(Comparator.comparing(LogItem::occurredAt).reversed())
                .toList();
        List<LogItem> page = items.stream()
                .skip(offset)
                .limit(limit)
                .toList();
        return new LogList(page, items.size());
    }

    private LogAction parseArchiveLogAction(String type) {
        if (type == null || type.isBlank()) {
            return null;
        }

        if ("ARCHIVE_QUERY".equalsIgnoreCase(type)) {
            return LogAction.ARCHIVE_QUERY;
        }

        if ("ARCHIVE_EXPORT".equalsIgnoreCase(type)) {
            return LogAction.ARCHIVE_EXPORT;
        }

        return null;
    }

    private boolean isAuditArchiveType(String type) {
        return "ARCHIVE_QUERY".equalsIgnoreCase(type)
                || "ARCHIVE_EXPORT".equalsIgnoreCase(type);
    }

    private boolean shouldIncludeArchiveLogEntries(String type) {
        return type == null || type.isBlank() || isAuditArchiveType(type);
    }

    private boolean isArchiveLogAction(LogAction action) {
        return action == LogAction.ARCHIVE_QUERY
                || action == LogAction.ARCHIVE_EXPORT;
    }
}

