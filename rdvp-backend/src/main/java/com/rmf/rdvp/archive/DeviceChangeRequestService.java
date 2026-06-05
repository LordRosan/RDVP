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
public class DeviceChangeRequestService {

    private static final Duration CHANGE_FREEZE_DURATION = Duration.ofHours(12);
    private static final Pattern REQUEST_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Set<String> SUPPORTED_FIELDS = Set.of("name", "model", "manufacturer", "location.address");
    private static final Set<String> DELETE_BLOCKING_STATUSES = Set.of("FAULTED", "UNDER_REPAIR", "PENDING_REINSPECTION");

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceChangeRequestRepository changeRequestRepository;
    private final UserAccountRepository userStore;
    private final AuditLogService auditLogService;

    public DeviceChangeRequestService(
            DeviceArchiveRepository archiveRepository,
            DeviceChangeRequestRepository changeRequestRepository,
            UserAccountRepository userStore,
            AuditLogService auditLogService) {
        this.archiveRepository = archiveRepository;
        this.changeRequestRepository = changeRequestRepository;
        this.userStore = userStore;
        this.auditLogService = auditLogService;
    }

    @Transactional
    public DeviceChangeRequest create(
            DeviceChangeRequestType type,
            String deviceId,
            String deviceCode,
            String reason,
            Map<String, DeviceChangeValue> changes,
            AuthenticatedUser applicant) {
        DeviceChangeRequestType requestType = type == null ? DeviceChangeRequestType.UPDATE : type;
        return switch (requestType) {
            case UPDATE -> createUpdateRequest(deviceId, reason, changes, applicant);
            case CREATE -> createArchiveCreateRequest(deviceCode, reason, changes, applicant);
            case DELETE -> createArchiveDeleteRequest(deviceId, reason, applicant);
        };
    }

    public DeviceChangeRequestPage list(
            String status,
            String deviceCode,
            String applicantId,
            int page,
            int pageSize) {
        DeviceChangeRequestStatus parsedStatus = parseStatus(status);
        String normalizedDeviceCode = deviceCode == null || deviceCode.isBlank()
                ? null
                : deviceCode.trim().toUpperCase();
        String normalizedApplicantId = applicantId == null || applicantId.isBlank() ? null : applicantId.trim();
        DeviceChangeRequestPage pageResult = changeRequestRepository.list(new DeviceChangeRequestQuery(
                parsedStatus,
                normalizedDeviceCode,
                normalizedApplicantId,
                normalizePage(page),
                normalizePageSize(pageSize)));
        return new DeviceChangeRequestPage(
                pageResult.items().stream().map(this::enrichApplicantName).toList(),
                pageResult.total());
    }

    @Transactional
    public DeviceChangeRequest review(
            String requestId,
            DeviceChangeReviewDecision decision,
            String reviewedAtText,
            String reviewComment,
            AuthenticatedUser reviewer) {
        String normalizedRequestId = normalizeRequiredId(requestId, "requestId");
        DeviceChangeRequest request = changeRequestRepository.findById(normalizedRequestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.CHANGE_REQUEST_NOT_FOUND));

        if (request.status() != DeviceChangeRequestStatus.PENDING_REVIEW) {
            throw new BusinessException(ErrorCode.CHANGE_REQUEST_ALREADY_REVIEWED);
        }

        OffsetDateTime reviewedAt = parseReviewedAt(reviewedAtText);
        String normalizedComment = reviewComment == null ? "" : reviewComment.trim();
        if (decision == DeviceChangeReviewDecision.REJECTED && normalizedComment.isBlank()) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    "Review comment is required when rejecting a change request.");
        }

        if (decision == DeviceChangeReviewDecision.APPROVED) {
            applyApprovedRequest(request, normalizedComment, reviewer, reviewedAt);
        } else {
            boolean reviewed = changeRequestRepository.applyRejectedReview(
                    request.id(),
                    reviewer.id(),
                    normalizedComment,
                    reviewedAt);
            if (!reviewed) {
                throw new BusinessException(ErrorCode.CHANGE_REQUEST_ALREADY_REVIEWED);
            }
        }

        DeviceChangeRequest reviewed = enrichApplicantName(changeRequestRepository.findById(request.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_CHANGE_REVIEW,
                reviewed.id(),
                reviewed.deviceCode(),
                reviewer,
                decision == DeviceChangeReviewDecision.APPROVED
                        ? "Device archive change request approved."
                        : "Device archive change request rejected.");
        return reviewed;
    }

    private DeviceChangeRequest createUpdateRequest(
            String deviceId,
            String reason,
            Map<String, DeviceChangeValue> changes,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_CHANGE_REQUEST_CREATE);
        DeviceArchive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (changeRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_LOCKED);
        }

        if (changeRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_FROZEN);
        }

        Map<String, DeviceChangeValue> normalizedChanges = normalizeAndValidateUpdateChanges(device, changes);
        DeviceChangeRequest created = createRequest(new DeviceChangeRequestCreate(
                newRequestId(),
                DeviceChangeRequestType.UPDATE,
                device.id(),
                device.deviceCode(),
                applicant.id(),
                device.status(),
                normalizeRequiredText(reason, "reason", 500),
                normalizedChanges,
                now));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_CHANGE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted device archive update request.");
        return created;
    }

    private DeviceChangeRequest createArchiveCreateRequest(
            String deviceCode,
            String reason,
            Map<String, DeviceChangeValue> changes,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_DEVICE_CREATE);
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        if (archiveRepository.existsByCode(normalizedDeviceCode)
                || changeRequestRepository.hasPendingByTargetDeviceCode(normalizedDeviceCode)) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
        }

        Map<String, DeviceChangeValue> normalizedChanges = normalizeAndValidateCreateChanges(changes);
        DeviceChangeRequest created = createRequest(new DeviceChangeRequestCreate(
                newRequestId(),
                DeviceChangeRequestType.CREATE,
                null,
                normalizedDeviceCode,
                applicant.id(),
                "NEW",
                normalizeRequiredText(reason, "reason", 500),
                normalizedChanges,
                now()));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_CHANGE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted device archive create request.");
        return created;
    }

    private DeviceChangeRequest createArchiveDeleteRequest(
            String deviceId,
            String reason,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_DEVICE_DELETE);
        DeviceArchive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (changeRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_LOCKED);
        }

        if (changeRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()
                || DELETE_BLOCKING_STATUSES.contains(device.status())) {
            throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_DELETE_BLOCKED);
        }

        DeviceChangeRequest created = createRequest(new DeviceChangeRequestCreate(
                newRequestId(),
                DeviceChangeRequestType.DELETE,
                device.id(),
                device.deviceCode(),
                applicant.id(),
                device.status(),
                normalizeRequiredText(reason, "reason", 500),
                buildDeleteSnapshot(device),
                now));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_CHANGE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted device archive delete request.");
        return created;
    }

    private DeviceChangeRequest createRequest(DeviceChangeRequestCreate request) {
        try {
            changeRequestRepository.create(request);
        } catch (DataIntegrityViolationException exception) {
            throw createConstraintConflict(request);
        }

        return enrichApplicantName(changeRequestRepository.findById(request.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
    }

    private void applyApprovedRequest(
            DeviceChangeRequest request,
            String reviewComment,
            AuthenticatedUser reviewer,
            OffsetDateTime reviewedAt) {
        switch (request.type()) {
            case UPDATE -> {
                DeviceArchive currentDevice = archiveRepository.findById(request.deviceId())
                        .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
                DeviceArchiveUpdate archiveUpdate = buildArchiveUpdate(currentDevice, request.changes(), reviewer.id(), reviewedAt);
                OffsetDateTime freezeUntil = reviewedAt.plus(CHANGE_FREEZE_DURATION);
                boolean reviewed = changeRequestRepository.applyApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        freezeUntil,
                        archiveUpdate);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.CHANGE_REQUEST_ALREADY_REVIEWED);
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

                boolean reviewed = changeRequestRepository.markApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        null);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.CHANGE_REQUEST_ALREADY_REVIEWED);
                }
            }
            case DELETE -> {
                DeviceArchive currentDevice = archiveRepository.findById(request.deviceId())
                        .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
                if (DELETE_BLOCKING_STATUSES.contains(currentDevice.status())
                        || changeRequestRepository.findActiveFreezeUntil(currentDevice.id(), reviewedAt).isPresent()) {
                    throw new BusinessException(ErrorCode.DEVICE_ARCHIVE_DELETE_BLOCKED);
                }

                boolean deleted = archiveRepository.softDelete(currentDevice.id(), reviewer.id(), reviewComment);
                if (!deleted) {
                    throw new BusinessException(ErrorCode.DEVICE_NOT_FOUND);
                }

                boolean reviewed = changeRequestRepository.markApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        null);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.CHANGE_REQUEST_ALREADY_REVIEWED);
                }
            }
        }
    }

    private BusinessException createConstraintConflict(DeviceChangeRequestCreate request) {
        if (request.type() == DeviceChangeRequestType.CREATE) {
            return new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
        }

        return new BusinessException(ErrorCode.DEVICE_CHANGE_LOCKED);
    }

    private Map<String, DeviceChangeValue> normalizeAndValidateUpdateChanges(
            DeviceArchive device,
            Map<String, DeviceChangeValue> changes) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        }

        Map<String, DeviceChangeValue> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, DeviceChangeValue> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            DeviceChangeValue value = requireChangeValue(entry.getValue());
            if (value.oldValue() == null) {
                throw new BusinessException(
                        ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                        "oldValue is required when updating a device archive.");
            }

            String currentValue = currentFieldValue(device, field);
            String oldValue = normalizeText(value.oldValue());
            String newValue = normalizeChangeValue(field, value.newValue(), true);
            if (!oldValue.equals(currentValue)) {
                throw new BusinessException(ErrorCode.CONFLICT, "Archive baseline is stale.");
            }

            if (!newValue.equals(currentValue)) {
                normalizedChanges.put(field, new DeviceChangeValue(currentValue, newValue));
            }
        }

        if (normalizedChanges.isEmpty()) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    "At least one archive field must change.");
        }

        return Map.copyOf(normalizedChanges);
    }

    private Map<String, DeviceChangeValue> normalizeAndValidateCreateChanges(Map<String, DeviceChangeValue> changes) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        }

        Map<String, DeviceChangeValue> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, DeviceChangeValue> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            DeviceChangeValue value = requireChangeValue(entry.getValue());
            String newValue = normalizeChangeValue(field, value.newValue(), "name".equals(field));
            if (!newValue.isBlank()) {
                normalizedChanges.put(field, new DeviceChangeValue("", newValue));
            }
        }

        if (!normalizedChanges.containsKey("name")) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    "name is required when creating a device archive.");
        }

        return Map.copyOf(normalizedChanges);
    }

    private Map<String, DeviceChangeValue> buildDeleteSnapshot(DeviceArchive device) {
        Map<String, DeviceChangeValue> snapshot = new HashMap<>();
        snapshot.put("name", new DeviceChangeValue(normalizeText(device.name()), ""));
        snapshot.put("model", new DeviceChangeValue(normalizeText(device.model()), ""));
        snapshot.put("manufacturer", new DeviceChangeValue(normalizeText(device.manufacturer()), ""));
        snapshot.put("location.address", new DeviceChangeValue(normalizeText(device.address()), ""));
        return Map.copyOf(snapshot);
    }

    private DeviceArchiveCreate buildArchiveCreate(DeviceChangeRequest request, String reviewerId, OffsetDateTime reviewedAt) {
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
            Map<String, DeviceChangeValue> changes,
            String reviewerId,
            OffsetDateTime reviewedAt) {
        String name = currentDevice.name();
        String model = currentDevice.model();
        String manufacturer = currentDevice.manufacturer();
        String address = currentDevice.address();

        for (Map.Entry<String, DeviceChangeValue> entry : changes.entrySet()) {
            switch (entry.getKey()) {
                case "name" -> name = entry.getValue().newValue();
                case "model" -> model = entry.getValue().newValue();
                case "manufacturer" -> manufacturer = entry.getValue().newValue();
                case "location.address" -> address = entry.getValue().newValue();
                default -> throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
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
            default -> throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        };
    }

    private String normalizeChangeValue(String field, String value, boolean required) {
        int maxLength = switch (field) {
            case "name", "model" -> 80;
            case "manufacturer" -> 100;
            case "location.address" -> 200;
            default -> throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        };
        return required ? normalizeRequiredText(value, field, maxLength) : normalizeOptionalText(value, maxLength);
    }

    private String normalizeSupportedField(String field) {
        String normalized = field == null ? "" : field.trim();
        if (!SUPPORTED_FIELDS.contains(normalized)) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    "Unsupported archive change field: " + normalized);
        }

        return normalized;
    }

    private DeviceChangeValue requireChangeValue(DeviceChangeValue value) {
        if (value == null) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
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

    private String requireCreatedValue(DeviceChangeRequest request, String field) {
        String value = createdValue(request, field);
        if (value.isBlank()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        }

        return value;
    }

    private String createdValue(DeviceChangeRequest request, String field) {
        DeviceChangeValue value = request.changes().get(field);
        return value == null ? "" : normalizeText(value.newValue());
    }

    private String normalizeRequiredText(String value, String field, int maxLength) {
        String normalized = normalizeOptionalText(value, maxLength);
        if (normalized.isBlank()) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    field + " is required and must not exceed " + maxLength + " characters.");
        }

        return normalized;
    }

    private String normalizeOptionalText(String value, int maxLength) {
        String normalized = normalizeText(value);
        if (normalized.length() > maxLength) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        }

        return normalized;
    }

    private String normalizeText(String value) {
        return value == null ? "" : value.trim();
    }

    private String normalizeRequiredId(String id, String field) {
        String normalized = id == null ? "" : id.trim();
        if (!REQUEST_ID_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }

        return normalized;
    }

    private DeviceChangeRequestStatus parseStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }

        try {
            return DeviceChangeRequestStatus.valueOf(status.trim().toUpperCase());
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
        return Math.max(page, 1);
    }

    private int normalizePageSize(int pageSize) {
        if (pageSize <= 0) {
            return 20;
        }

        return Math.min(pageSize, 100);
    }

    private String newRequestId() {
        return "DCR-" + UUID.randomUUID();
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }

    private DeviceChangeRequest enrichApplicantName(DeviceChangeRequest request) {
        String applicantName = userStore.findById(request.applicantId())
                .map(user -> user.displayName())
                .orElse(request.applicantId());
        return new DeviceChangeRequest(
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
                request.createdAt(),
                request.reviewerId(),
                request.reviewComment(),
                request.reviewedAt(),
                request.freezeUntil());
    }
}
