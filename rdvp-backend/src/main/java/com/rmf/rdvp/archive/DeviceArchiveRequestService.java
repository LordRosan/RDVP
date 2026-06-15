package com.rmf.rdvp.archive;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.identity.UserAccountRepository;

@Service
public class DeviceArchiveRequestService {

    private static final Duration ARCHIVE_REQUEST_FREEZE_DURATION = Duration.ofHours(6);
    private static final int MAX_PAGE_NUMBER = 10_000;
    private static final int MAX_PAGE_SIZE = 100;
    private static final Pattern REQUEST_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Set<String> SUPPORTED_FIELDS = Set.of("name", "model", "manufacturer", "location.address");
    private static final Set<String> DELETE_BLOCKING_STATUSES = Set.of("FAULTED", "UNDER_REPAIR", "PENDING_REINSPECTION");

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceArchiveRequestRepository archiveRequestRepository;
    private final UserAccountRepository userStore;
    private final AuditLogService auditLogService;

    public DeviceArchiveRequestService(
            DeviceArchiveRepository archiveRepository,
            DeviceArchiveRequestRepository archiveRequestRepository,
            UserAccountRepository userStore,
            AuditLogService auditLogService) {
        this.archiveRepository = archiveRepository;
        this.archiveRequestRepository = archiveRequestRepository;
        this.userStore = userStore;
        this.auditLogService = auditLogService;
    }

    @Transactional
    public DeviceArchiveRequest create(
            DeviceArchiveRequestType type,
            String deviceId,
            String deviceCode,
            String reason,
            Map<String, DeviceArchiveFieldChange> changes,
            AuthenticatedUser applicant) {
        return create(type, deviceId, deviceCode, reason, changes, null, applicant);
    }

    @Transactional
    public DeviceArchiveRequest create(
            DeviceArchiveRequestType type,
            String deviceId,
            String deviceCode,
            String reason,
            Map<String, DeviceArchiveFieldChange> changes,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        DeviceArchiveRequestType requestType = type == null ? DeviceArchiveRequestType.UPDATE : type;
        try {
            return switch (requestType) {
                case UPDATE -> createUpdateRequest(deviceId, reason, changes, initiatedAt, applicant);
                case CREATE -> createArchiveCreateRequest(deviceCode, reason, changes, initiatedAt, applicant);
                case DELETE -> createArchiveDeleteRequest(deviceId, reason, initiatedAt, applicant);
            };
        } catch (BusinessException exception) {
            recordArchiveRequestFailure(requestType, deviceId, deviceCode, applicant, exception);
            throw exception;
        }
    }

    public DeviceArchiveRequestPage list(
            String status,
            String deviceCode,
            String applicantId,
            int page,
            int pageSize) {
        DeviceArchiveRequestStatus parsedStatus = parseStatus(status);
        String normalizedDeviceCode = deviceCode == null || deviceCode.isBlank()
                ? null
                : deviceCode.trim().toUpperCase();
        String normalizedApplicantId = applicantId == null || applicantId.isBlank() ? null : applicantId.trim();
        DeviceArchiveRequestPage pageResult = archiveRequestRepository.list(new DeviceArchiveRequestQuery(
                parsedStatus,
                normalizedDeviceCode,
                normalizedApplicantId,
                null,
                normalizePage(page),
                normalizePageSize(pageSize)));
        return new DeviceArchiveRequestPage(
                pageResult.items().stream().map(this::enrichApplicantName).toList(),
                pageResult.total());
    }

    public boolean hasPendingCreateRequestByDeviceCode(String deviceCode) {
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        return archiveRequestRepository.hasPendingByTargetDeviceCode(normalizedDeviceCode);
    }

    @Transactional
    public DeviceArchiveRequest review(
            String requestId,
            DeviceArchiveReviewDecision decision,
            String reviewedAtText,
            String reviewComment,
            AuthenticatedUser reviewer) {
        String normalizedRequestId = normalizeText(requestId);
        DeviceArchiveRequest request = null;
        try {
            normalizedRequestId = normalizeRequiredId(requestId, "requestId");
            request = archiveRequestRepository.findById(normalizedRequestId)
                    .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_NOT_FOUND));

            if (request.status() != DeviceArchiveRequestStatus.PENDING_REVIEW) {
                throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_ALREADY_REVIEWED);
            }

            OffsetDateTime reviewedAt = parseReviewedAt(reviewedAtText);
            String normalizedComment = reviewComment == null ? "" : reviewComment.trim();
            if (decision == DeviceArchiveReviewDecision.REJECTED && normalizedComment.isBlank()) {
                throw new BusinessException(
                        ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID,
                        "Review comment is required when rejecting an archive request.");
            }

            if (decision == DeviceArchiveReviewDecision.APPROVED) {
                applyApprovedRequest(request, normalizedComment, reviewer, reviewedAt);
            } else {
                boolean reviewed = archiveRequestRepository.applyRejectedReview(
                        request.id(),
                        reviewer.id(),
                        normalizedComment,
                        reviewedAt);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
            }

            DeviceArchiveRequest reviewed = enrichApplicantName(archiveRequestRepository.findById(request.id())
                    .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
            auditLogService.recordSuccess(
                    AuditAction.DEVICE_ARCHIVE_REVIEW,
                    reviewed.id(),
                    reviewed.deviceCode(),
                    reviewer,
                    decision == DeviceArchiveReviewDecision.APPROVED
                            ? "Device archive request approved."
                            : "Device archive request rejected.");
            return reviewed;
        } catch (BusinessException exception) {
            recordArchiveReviewFailure(normalizedRequestId, request, reviewer, exception);
            throw exception;
        }
    }

    private void recordArchiveRequestFailure(
            DeviceArchiveRequestType requestType,
            String deviceId,
            String deviceCode,
            AuthenticatedUser applicant,
            BusinessException exception) {
        auditLogService.recordFailure(
                AuditAction.DEVICE_ARCHIVE_REQUEST,
                requestType == DeviceArchiveRequestType.CREATE ? null : normalizeAuditTarget(deviceId),
                resolveArchiveRequestTargetNo(deviceId, deviceCode),
                applicant,
                "设备档案%s申请提交失败：%s。".formatted(formatRequestType(requestType), exception.getErrorCode().code()));
    }

    private void recordArchiveReviewFailure(
            String requestId,
            DeviceArchiveRequest request,
            AuthenticatedUser reviewer,
            BusinessException exception) {
        auditLogService.recordFailure(
                AuditAction.DEVICE_ARCHIVE_REVIEW,
                request == null ? requestId : request.id(),
                request == null ? requestId : request.deviceCode(),
                reviewer,
                "设备档案审核提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private DeviceArchiveRequest createUpdateRequest(
            String deviceId,
            String reason,
            Map<String, DeviceArchiveFieldChange> changes,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT);
        DeviceArchive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (archiveRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_LOCKED);
        }

        if (archiveRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_FROZEN);
        }

        Map<String, DeviceArchiveFieldChange> normalizedChanges = normalizeAndValidateUpdateChanges(device, changes);
        DeviceArchiveRequest created = createRequest(new DeviceArchiveRequestCreate(
                newRequestId(),
                DeviceArchiveRequestType.UPDATE,
                device.id(),
                device.deviceCode(),
                applicant.id(),
                device.status(),
                normalizeRequiredText(reason, "reason", 500),
                normalizedChanges,
                normalizeInitiatedAt(initiatedAt, now),
                now));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_ARCHIVE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted device archive update request.");
        return created;
    }

    private DeviceArchiveRequest createArchiveCreateRequest(
            String deviceCode,
            String reason,
            Map<String, DeviceArchiveFieldChange> changes,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT);
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        if (archiveRepository.existsByCode(normalizedDeviceCode)
                || archiveRequestRepository.hasPendingByTargetDeviceCode(normalizedDeviceCode)) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
        }

        OffsetDateTime submittedAt = now();
        Map<String, DeviceArchiveFieldChange> normalizedChanges = normalizeAndValidateCreateChanges(changes);
        DeviceArchiveRequest created = createRequest(new DeviceArchiveRequestCreate(
                newRequestId(),
                DeviceArchiveRequestType.CREATE,
                null,
                normalizedDeviceCode,
                applicant.id(),
                "NEW",
                normalizeRequiredText(reason, "reason", 500),
                normalizedChanges,
                normalizeInitiatedAt(initiatedAt, submittedAt),
                submittedAt));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_ARCHIVE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted device archive create request.");
        return created;
    }

    private DeviceArchiveRequest createArchiveDeleteRequest(
            String deviceId,
            String reason,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT);
        DeviceArchive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (archiveRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_LOCKED);
        }

        if (archiveRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()
                || DELETE_BLOCKING_STATUSES.contains(device.status())) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_DELETE_BLOCKED);
        }

        DeviceArchiveRequest created = createRequest(new DeviceArchiveRequestCreate(
                newRequestId(),
                DeviceArchiveRequestType.DELETE,
                device.id(),
                device.deviceCode(),
                applicant.id(),
                device.status(),
                normalizeRequiredText(reason, "reason", 500),
                buildDeleteSnapshot(device),
                normalizeInitiatedAt(initiatedAt, now),
                now));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_ARCHIVE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted device archive delete request.");
        return created;
    }

    private DeviceArchiveRequest createRequest(DeviceArchiveRequestCreate request) {
        try {
            archiveRequestRepository.create(request);
        } catch (DataIntegrityViolationException exception) {
            throw createConstraintConflict(request);
        }

        return enrichApplicantName(archiveRequestRepository.findById(request.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
    }

    private void applyApprovedRequest(
            DeviceArchiveRequest request,
            String reviewComment,
            AuthenticatedUser reviewer,
            OffsetDateTime reviewedAt) {
        switch (request.type()) {
            case UPDATE -> {
                DeviceArchive currentDevice = archiveRepository.findById(request.deviceId())
                        .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
                verifyApprovalBaseline(currentDevice, request.changes());
                DeviceArchiveUpdate archiveUpdate = buildArchiveUpdate(currentDevice, request.changes(), reviewer.id(), reviewedAt);
                OffsetDateTime freezeUntil = reviewedAt.plus(ARCHIVE_REQUEST_FREEZE_DURATION);
                boolean reviewed = archiveRequestRepository.applyApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        freezeUntil,
                        archiveUpdate);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
            }
            case CREATE -> {
                if (archiveRepository.existsByCode(request.deviceCode())) {
                    throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
                }

                try {
                    archiveRepository.create(buildArchiveCreate(request, reviewer.id(), reviewedAt));
                } catch (DataIntegrityViolationException exception) {
                    throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
                }

                boolean reviewed = archiveRequestRepository.markApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        null);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
            }
            case DELETE -> {
                DeviceArchive currentDevice = archiveRepository.findById(request.deviceId())
                        .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
                verifyApprovalBaseline(currentDevice, request.changes());
                if (DELETE_BLOCKING_STATUSES.contains(currentDevice.status())
                        || archiveRequestRepository.findActiveFreezeUntil(currentDevice.id(), reviewedAt).isPresent()) {
                    throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_DELETE_BLOCKED);
                }

                boolean deleted = archiveRepository.softDelete(currentDevice.id(), reviewer.id(), reviewComment);
                if (!deleted) {
                    throw new BusinessException(ErrorCode.DEVICE_NOT_FOUND);
                }

                boolean reviewed = archiveRequestRepository.markApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        null);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
            }
        }
    }

    private void verifyApprovalBaseline(DeviceArchive currentDevice, Map<String, DeviceArchiveFieldChange> changes) {
        for (Map.Entry<String, DeviceArchiveFieldChange> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            DeviceArchiveFieldChange value = requireChangeValue(entry.getValue());
            String expectedOldValue = normalizeText(value.oldValue());
            String currentValue = currentFieldValue(currentDevice, field);
            if (!expectedOldValue.equals(currentValue)) {
                throw new BusinessException(ErrorCode.CONFLICT, "Archive baseline changed before approval.");
            }
        }
    }

    private BusinessException createConstraintConflict(DeviceArchiveRequestCreate request) {
        if (request.type() == DeviceArchiveRequestType.CREATE) {
            return new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
        }

        return new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_LOCKED);
    }

    private Map<String, DeviceArchiveFieldChange> normalizeAndValidateUpdateChanges(
            DeviceArchive device,
            Map<String, DeviceArchiveFieldChange> changes) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        }

        Map<String, DeviceArchiveFieldChange> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, DeviceArchiveFieldChange> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            DeviceArchiveFieldChange value = requireChangeValue(entry.getValue());
            if (value.oldValue() == null) {
                throw new BusinessException(
                        ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID,
                        "oldValue is required when updating a device archive.");
            }

            String currentValue = currentFieldValue(device, field);
            String oldValue = normalizeText(value.oldValue());
            String newValue = normalizeChangeValue(field, value.newValue(), true);
            if (!oldValue.equals(currentValue)) {
                throw new BusinessException(ErrorCode.CONFLICT, "Archive baseline is stale.");
            }

            if (!newValue.equals(currentValue)) {
                normalizedChanges.put(field, new DeviceArchiveFieldChange(currentValue, newValue));
            }
        }

        if (normalizedChanges.isEmpty()) {
            throw new BusinessException(
                    ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID,
                    "At least one archive field must change.");
        }

        return Map.copyOf(normalizedChanges);
    }

    private Map<String, DeviceArchiveFieldChange> normalizeAndValidateCreateChanges(Map<String, DeviceArchiveFieldChange> changes) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        }

        Map<String, DeviceArchiveFieldChange> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, DeviceArchiveFieldChange> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            DeviceArchiveFieldChange value = requireChangeValue(entry.getValue());
            String newValue = normalizeChangeValue(field, value.newValue(), "name".equals(field));
            if (!newValue.isBlank()) {
                normalizedChanges.put(field, new DeviceArchiveFieldChange("", newValue));
            }
        }

        if (!normalizedChanges.containsKey("name")) {
            throw new BusinessException(
                    ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID,
                    "name is required when creating a device archive.");
        }

        return Map.copyOf(normalizedChanges);
    }

    private Map<String, DeviceArchiveFieldChange> buildDeleteSnapshot(DeviceArchive device) {
        Map<String, DeviceArchiveFieldChange> snapshot = new HashMap<>();
        snapshot.put("name", new DeviceArchiveFieldChange(normalizeText(device.name()), ""));
        snapshot.put("model", new DeviceArchiveFieldChange(normalizeText(device.model()), ""));
        snapshot.put("manufacturer", new DeviceArchiveFieldChange(normalizeText(device.manufacturer()), ""));
        snapshot.put("location.address", new DeviceArchiveFieldChange(normalizeText(device.address()), ""));
        return Map.copyOf(snapshot);
    }

    private DeviceArchiveCreate buildArchiveCreate(DeviceArchiveRequest request, String reviewerId, OffsetDateTime reviewedAt) {
        return new DeviceArchiveCreate(
                "device-" + UUID.randomUUID(),
                request.deviceCode(),
                requireCreatedValue(request, "name"),
                createdValue(request, "model"),
                createdValue(request, "manufacturer"),
                "PENDING_VERIFICATION",
                createdValue(request, "location.address"),
                null,
                null,
                reviewerId,
                reviewedAt);
    }

    private DeviceArchiveUpdate buildArchiveUpdate(
            DeviceArchive currentDevice,
            Map<String, DeviceArchiveFieldChange> changes,
            String reviewerId,
            OffsetDateTime reviewedAt) {
        String name = currentDevice.name();
        String model = currentDevice.model();
        String manufacturer = currentDevice.manufacturer();
        String address = currentDevice.address();

        for (Map.Entry<String, DeviceArchiveFieldChange> entry : changes.entrySet()) {
            switch (entry.getKey()) {
                case "name" -> name = entry.getValue().newValue();
                case "model" -> model = entry.getValue().newValue();
                case "manufacturer" -> manufacturer = entry.getValue().newValue();
                case "location.address" -> address = entry.getValue().newValue();
                default -> throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
            }
        }

        return new DeviceArchiveUpdate(currentDevice.id(), name, model, manufacturer, address, reviewerId, reviewedAt);
    }

    private String currentFieldValue(DeviceArchive device, String field) {
        return switch (field) {
            case "name" -> normalizeText(device.name());
            case "model" -> normalizeText(device.model());
            case "manufacturer" -> normalizeText(device.manufacturer());
            case "location.address" -> normalizeText(device.address());
            default -> throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        };
    }

    private String normalizeChangeValue(String field, String value, boolean required) {
        int maxLength = switch (field) {
            case "name", "model" -> 80;
            case "manufacturer" -> 100;
            case "location.address" -> 200;
            default -> throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        };
        return required ? normalizeRequiredText(value, field, maxLength) : normalizeOptionalText(value, maxLength);
    }

    private String normalizeSupportedField(String field) {
        String normalized = field == null ? "" : field.trim();
        if (!SUPPORTED_FIELDS.contains(normalized)) {
            throw new BusinessException(
                    ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID,
                    "Unsupported archive request field: " + normalized);
        }

        return normalized;
    }

    private DeviceArchiveFieldChange requireChangeValue(DeviceArchiveFieldChange value) {
        if (value == null) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        }

        return value;
    }

    private String normalizeDeviceCode(String deviceCode) {
        String normalized = deviceCode == null ? "" : deviceCode.trim().toUpperCase();
        if (!DEVICE_CODE_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_INVALID);
        }

        return normalized;
    }

    private void requirePermission(AuthenticatedUser user, PermissionCode permission) {
        if (user == null || !user.permissions().contains(permission)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private String requireCreatedValue(DeviceArchiveRequest request, String field) {
        String value = createdValue(request, field);
        if (value.isBlank()) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        }

        return value;
    }

    private String createdValue(DeviceArchiveRequest request, String field) {
        DeviceArchiveFieldChange value = request.changes().get(field);
        return value == null ? "" : normalizeText(value.newValue());
    }

    private String normalizeRequiredText(String value, String field, int maxLength) {
        String normalized = normalizeOptionalText(value, maxLength);
        if (normalized.isBlank()) {
            throw new BusinessException(
                    ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID,
                    field + " is required and must not exceed " + maxLength + " characters.");
        }

        return normalized;
    }

    private String normalizeOptionalText(String value, int maxLength) {
        String normalized = normalizeText(value);
        if (normalized.length() > maxLength) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_REQUEST_INVALID);
        }

        return normalized;
    }

    private String normalizeText(String value) {
        return value == null ? "" : value.trim();
    }

    private OffsetDateTime normalizeInitiatedAt(OffsetDateTime initiatedAt, OffsetDateTime submittedAt) {
        return initiatedAt == null ? submittedAt : initiatedAt.withOffsetSameInstant(ZoneOffset.UTC);
    }

    private String normalizeAuditTarget(String value) {
        String normalized = normalizeText(value);
        return normalized.isBlank() ? null : normalized;
    }

    private String resolveArchiveRequestTargetNo(String deviceId, String deviceCode) {
        String normalizedDeviceCode = normalizeAuditTarget(deviceCode);
        if (normalizedDeviceCode != null) {
            return normalizedDeviceCode.toUpperCase();
        }

        String normalizedDeviceId = normalizeAuditTarget(deviceId);
        if (normalizedDeviceId == null) {
            return null;
        }

        try {
            return archiveRepository.findById(normalizedDeviceId)
                    .map(DeviceArchive::deviceCode)
                    .orElse(normalizedDeviceId);
        } catch (RuntimeException exception) {
            return normalizedDeviceId;
        }
    }

    private String formatRequestType(DeviceArchiveRequestType requestType) {
        return switch (requestType) {
            case UPDATE -> "修改";
            case CREATE -> "新增";
            case DELETE -> "删除";
        };
    }

    private String normalizeRequiredId(String id, String field) {
        String normalized = id == null ? "" : id.trim();
        if (!REQUEST_ID_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }

        return normalized;
    }

    private DeviceArchiveRequestStatus parseStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }

        try {
            return DeviceArchiveRequestStatus.valueOf(status.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "status is invalid.");
        }
    }

    private OffsetDateTime parseReviewedAt(String reviewedAtText) {
        if (reviewedAtText == null || reviewedAtText.isBlank()) {
            return now();
        }

        try {
            return OffsetDateTime.parse(reviewedAtText.trim()).withOffsetSameInstant(ZoneOffset.UTC);
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "reviewedAt is invalid.");
        }
    }

    private int normalizePage(int page) {
        return Math.min(Math.max(page, 1), MAX_PAGE_NUMBER);
    }

    private int normalizePageSize(int pageSize) {
        if (pageSize <= 0) {
            return 20;
        }

        return Math.min(pageSize, MAX_PAGE_SIZE);
    }

    private String newRequestId() {
        return "DCR-" + UUID.randomUUID();
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }

    private DeviceArchiveRequest enrichApplicantName(DeviceArchiveRequest request) {
        String applicantName = userStore.findById(request.applicantId())
                .map(user -> user.displayName())
                .orElse(request.applicantId());
        return new DeviceArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                applicantName,
                request.status(),
                request.reason(),
                request.changes(),
                request.initiatedAt(),
                request.createdAt(),
                request.reviewerId(),
                request.reviewComment(),
                request.reviewedAt(),
                request.freezeUntil());
    }
}


