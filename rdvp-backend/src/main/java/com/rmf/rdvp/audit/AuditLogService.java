package com.rmf.rdvp.audit;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;

@Service
public class AuditLogService {

    private static final int DEFAULT_PAGE_SIZE = 20;
    private static final int MAX_PAGE_SIZE = 100;
    private static final int MAX_TARGET_TEXT_LENGTH = 128;
    private static final int MAX_DESCRIPTION_LENGTH = 500;

    private final AuditLogRepository auditLogRepository;

    public AuditLogService(AuditLogRepository auditLogRepository) {
        this.auditLogRepository = auditLogRepository;
    }

    public void recordSuccess(
            AuditAction action,
            String targetId,
            String targetNo,
            AuthenticatedUser actor,
            String description) {
        record(
                action,
                targetId,
                targetNo,
                actor == null ? null : actor.id(),
                actor == null ? null : actor.displayName(),
                AuditStatus.SUCCESS,
                description);
    }

    public void recordSuccess(
            AuditAction action,
            String targetId,
            String targetNo,
            String actorId,
            String actorName,
            String description) {
        record(action, targetId, targetNo, actorId, actorName, AuditStatus.SUCCESS, description);
    }

    public AuditLogPage list(String action, int page, int pageSize) {
        return auditLogRepository.list(new AuditLogQuery(
                parseAction(action),
                normalizePage(page),
                normalizePageSize(pageSize)));
    }

    private void record(
            AuditAction action,
            String targetId,
            String targetNo,
            String actorId,
            String actorName,
            AuditStatus status,
            String description) {
        if (action == null) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }

        auditLogRepository.append(new AuditLogCreate(
                "audit-" + UUID.randomUUID(),
                action,
                normalizeOptionalText(targetId, MAX_TARGET_TEXT_LENGTH),
                normalizeOptionalText(targetNo, MAX_TARGET_TEXT_LENGTH),
                normalizeOptionalText(actorId, MAX_TARGET_TEXT_LENGTH),
                normalizeOptionalText(actorName, MAX_TARGET_TEXT_LENGTH),
                status,
                normalizeOptionalText(description, MAX_DESCRIPTION_LENGTH),
                OffsetDateTime.now(ZoneOffset.UTC)));
    }

    private AuditAction parseAction(String action) {
        if (action == null || action.isBlank()) {
            return null;
        }

        try {
            return AuditAction.valueOf(action.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "action is invalid.");
        }
    }

    private int normalizePage(int page) {
        return Math.max(page, 1);
    }

    private int normalizePageSize(int pageSize) {
        if (pageSize <= 0) {
            return DEFAULT_PAGE_SIZE;
        }

        return Math.min(pageSize, MAX_PAGE_SIZE);
    }

    private String normalizeOptionalText(String value, int maxLength) {
        String normalized = value == null ? "" : value.trim();
        return normalized.length() <= maxLength ? normalized : normalized.substring(0, maxLength);
    }
}
