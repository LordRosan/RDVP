package com.rmf.rdvp.log;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;

@Service
public class LogQueryService {

    private static final int MAX_PAGE_SIZE = 100;

    private final LogQueryRepository logQueryRepository;

    public LogQueryService(LogQueryRepository logQueryRepository) {
        this.logQueryRepository = logQueryRepository;
    }

    public LogList queryLogs(
            String category,
            String type,
            String keyword,
            String startDate,
            String endDate,
            int page,
            int pageSize) {
        int limit = Math.min(pageSize > 0 ? pageSize : 20, MAX_PAGE_SIZE);
        int offset = Math.max(page - 1, 0) * limit;
        LogQueryTimeRange timeRange = createTimeRange(startDate, endDate);

        return switch (category.toUpperCase()) {
            case "ARCHIVE_OPERATION" -> logQueryRepository.queryArchiveLogs(type, keyword, timeRange, limit, offset);
            case "ARCHIVE_REVIEW" -> logQueryRepository.queryArchiveReviewLogs(type, keyword, timeRange, limit, offset);
            case "OPERATIONS_OPERATION" -> logQueryRepository.queryOperationsLogs(type, keyword, timeRange, limit, offset);
            case "OPERATIONS_REVIEW" -> logQueryRepository.queryOperationsReviewLogs(type, keyword, timeRange, limit, offset);
            default -> throw new IllegalArgumentException("Invalid category: " + category);
        };
    }

    private LogQueryTimeRange createTimeRange(String startDate, String endDate) {
        LocalDate start = parseDate(startDate, "startDate");
        LocalDate end = parseDate(endDate, "endDate");
        ZoneId zoneId = ZoneId.systemDefault();
        LocalDate today = LocalDate.now(zoneId);

        if (end != null && end.isAfter(today)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "endDate must not be later than today.");
        }

        if (start != null && end != null && start.isAfter(end)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "startDate must not be later than endDate.");
        }

        OffsetDateTime startInclusive = start == null ? null : start.atStartOfDay(zoneId).toOffsetDateTime();
        OffsetDateTime endExclusive = end == null ? null : end.plusDays(1).atStartOfDay(zoneId).toOffsetDateTime();
        return new LogQueryTimeRange(startInclusive, endExclusive);
    }

    private LocalDate parseDate(String value, String field) {
        if (value == null || value.isBlank()) {
            return null;
        }

        try {
            return LocalDate.parse(value.trim());
        } catch (DateTimeParseException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }
}
