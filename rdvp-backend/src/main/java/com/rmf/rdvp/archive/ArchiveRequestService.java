package com.rmf.rdvp.archive;

import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryService;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticatedUser;
import com.rmf.rdvp.user.PermissionCode;
import com.rmf.rdvp.user.UserAccountRepository;

@Service
public class ArchiveRequestService {

    private static final Duration ARCHIVE_REQUEST_FREEZE_DURATION = Duration.ofHours(6);
    private static final int MAX_PAGE_NUMBER = 10_000;
    private static final int MAX_PAGE_SIZE = 100;
    private static final Pattern REQUEST_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Set<String> SUPPORTED_FIELDS = Set.of(
            "name",
            "deviceType",
            "model",
            "manufacturer",
            "commissionedAt",
            "managementDepartment",
            "location.address");
    private static final Set<String> REQUIRED_CREATE_FIELDS = Set.of(
            "name",
            "deviceType",
            "model",
            "manufacturer",
            "commissionedAt",
            "managementDepartment",
            "location.address");
    private static final Set<String> DELETE_BLOCKING_STATUSES = Set.of("FAULTED", "UNDER_REPAIR", "PENDING_REINSPECTION");

    private final ArchiveRepository archiveRepository;
    private final ArchiveRequestRepository archiveRequestRepository;
    private final ArchiveImageService archiveImageService;
    private final DeviceQrCodeIssuer qrCodeIssuer;
    private final UserAccountRepository userStore;
    private final LogEntryService logEntryService;

    public ArchiveRequestService(
            ArchiveRepository archiveRepository,
            ArchiveRequestRepository archiveRequestRepository,
            ArchiveImageService archiveImageService,
            DeviceQrCodeIssuer qrCodeIssuer,
            UserAccountRepository userStore,
            LogEntryService logEntryService) {
        this.archiveRepository = archiveRepository;
        this.archiveRequestRepository = archiveRequestRepository;
        this.archiveImageService = archiveImageService;
        this.qrCodeIssuer = qrCodeIssuer;
        this.userStore = userStore;
        this.logEntryService = logEntryService;
    }

    @Transactional
    public ArchiveRequest create(
            ArchiveRequestType type,
            String deviceId,
            String deviceCode,
            String reason,
            Map<String, ArchiveFieldChange> changes,
            AuthenticatedUser applicant) {
        return create(type, deviceId, deviceCode, reason, changes, null, null, applicant);
    }

    @Transactional
    public ArchiveRequest create(
            ArchiveRequestType type,
            String deviceId,
            String deviceCode,
            String reason,
            Map<String, ArchiveFieldChange> changes,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        return create(type, deviceId, deviceCode, reason, changes, null, initiatedAt, applicant);
    }

    @Transactional
    public ArchiveRequest create(
            ArchiveRequestType type,
            String deviceId,
            String deviceCode,
            String reason,
            Map<String, ArchiveFieldChange> changes,
            List<ArchiveImageSubmission> images,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        ArchiveRequestType requestType = type == null ? ArchiveRequestType.UPDATE : type;
        try {
            return switch (requestType) {
                case UPDATE -> createUpdateRequest(deviceId, reason, changes, images, initiatedAt, applicant);
                case CREATE -> createArchiveCreateRequest(deviceCode, reason, changes, images, initiatedAt, applicant);
                case DELETE -> createArchiveDeleteRequest(deviceId, reason, images, initiatedAt, applicant);
            };
        } catch (BusinessException exception) {
            recordArchiveRequestFailure(requestType, deviceId, deviceCode, applicant, exception);
            throw exception;
        }
    }

    public ArchiveRequestPage list(
            String status,
            String deviceCode,
            String applicantId,
            int page,
            int pageSize) {
        ArchiveRequestStatus parsedStatus = parseStatus(status);
        String normalizedDeviceCode = deviceCode == null || deviceCode.isBlank()
                ? null
                : deviceCode.trim().toUpperCase();
        String normalizedApplicantId = applicantId == null || applicantId.isBlank() ? null : applicantId.trim();
        ArchiveRequestPage pageResult = archiveRequestRepository.list(new ArchiveRequestQuery(
                parsedStatus,
                normalizedDeviceCode,
                normalizedApplicantId,
                null,
                normalizePage(page),
                normalizePageSize(pageSize)));
        return new ArchiveRequestPage(
                pageResult.items().stream().map(this::enrichApplicantName).toList(),
                pageResult.total());
    }

    public boolean hasPendingCreateRequestByDeviceCode(String deviceCode) {
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        return archiveRequestRepository.hasPendingByTargetDeviceCode(normalizedDeviceCode);
    }

    @Transactional
    public ArchiveRequest review(
            String requestId,
            ArchiveReviewDecision decision,
            String reviewedAtText,
            String reviewComment,
            AuthenticatedUser reviewer) {
        String normalizedRequestId = normalizeText(requestId);
        ArchiveRequest request = null;
        try {
            normalizedRequestId = normalizeRequiredId(requestId, "requestId");
            request = archiveRequestRepository.findById(normalizedRequestId)
                    .orElseThrow(() -> new BusinessException(ErrorCode.ARCHIVE_REQUEST_NOT_FOUND));

            if (request.status() != ArchiveRequestStatus.PENDING_REVIEW) {
                throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_ALREADY_REVIEWED);
            }

            OffsetDateTime reviewedAt = parseReviewedAt(reviewedAtText);
            OffsetDateTime freezeUntil = reviewedAt.plus(ARCHIVE_REQUEST_FREEZE_DURATION);
            String normalizedComment = reviewComment == null ? "" : reviewComment.trim();
            if (decision == ArchiveReviewDecision.REJECTED && normalizedComment.isBlank()) {
                throw new BusinessException(
                        ErrorCode.ARCHIVE_REQUEST_INVALID,
                        "Review comment is required when rejecting an archive request.");
            }

            if (decision == ArchiveReviewDecision.APPROVED) {
                applyApprovedRequest(request, normalizedComment, reviewer, reviewedAt);
            } else {
                boolean reviewed = archiveRequestRepository.applyRejectedReview(
                        request.id(),
                        reviewer.id(),
                        normalizedComment,
                        reviewedAt,
                        freezeUntil);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
            }

            ArchiveRequest reviewed = enrichApplicantName(archiveRequestRepository.findById(request.id())
                    .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
            logEntryService.recordSuccess(
                    LogAction.ARCHIVE_REVIEW,
                    reviewed.id(),
                    reviewed.deviceCode(),
                    reviewer,
                    decision == ArchiveReviewDecision.APPROVED
                            ? "Archive request approved."
                            : "Archive request rejected.");
            return reviewed;
        } catch (BusinessException exception) {
            recordArchiveReviewFailure(normalizedRequestId, request, reviewer, exception);
            throw exception;
        }
    }

    private void recordArchiveRequestFailure(
            ArchiveRequestType requestType,
            String deviceId,
            String deviceCode,
            AuthenticatedUser applicant,
            BusinessException exception) {
        logEntryService.recordFailure(
                LogAction.ARCHIVE_REQUEST,
                requestType == ArchiveRequestType.CREATE ? null : normalizeLogTarget(deviceId),
                resolveArchiveRequestTargetNo(deviceId, deviceCode),
                applicant,
                "档案%s申请提交失败：%s。".formatted(formatRequestType(requestType), exception.getErrorCode().code()));
    }

    private void recordArchiveReviewFailure(
            String requestId,
            ArchiveRequest request,
            AuthenticatedUser reviewer,
            BusinessException exception) {
        logEntryService.recordFailure(
                LogAction.ARCHIVE_REVIEW,
                request == null ? requestId : request.id(),
                request == null ? requestId : request.deviceCode(),
                reviewer,
                "档案审核提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private ArchiveRequest createUpdateRequest(
            String deviceId,
            String reason,
            Map<String, ArchiveFieldChange> changes,
            List<ArchiveImageSubmission> images,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_CENTER_ARCHIVE_UPDATE_REQUEST_SUBMIT);
        Archive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (archiveRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_LOCKED);
        }

        if (archiveRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_FROZEN);
        }

        Optional<List<ArchiveImage>> imageChange = archiveImageService.prepareChange(device.id(), images);
        Map<String, ArchiveFieldChange> normalizedChanges = normalizeAndValidateUpdateChanges(
                device, changes, imageChange.isPresent());
        String requestId = newRequestId();
        ArchiveRequest created = createRequest(new ArchiveRequestCreate(
                requestId,
                ArchiveRequestType.UPDATE,
                device.id(),
                device.deviceCode(),
                applicant.id(),
                device.status(),
                normalizeRequiredText(reason, "reason", 500),
                normalizedChanges,
                normalizeInitiatedAt(initiatedAt, now),
                now));
        imageChange.ifPresent(value -> archiveImageService.savePendingChange(requestId, value));
        logEntryService.recordSuccess(
                LogAction.ARCHIVE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted archive update request.");
        return created;
    }

    private ArchiveRequest createArchiveCreateRequest(
            String deviceCode,
            String reason,
            Map<String, ArchiveFieldChange> changes,
            List<ArchiveImageSubmission> images,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        requirePermission(applicant, PermissionCode.ARCHIVE_CENTER_ARCHIVE_CREATE_REQUEST_SUBMIT);
        String normalizedDeviceCode = normalizeDeviceCode(deviceCode);
        if (archiveRequestRepository.findActiveFreezeUntilByTargetDeviceCode(normalizedDeviceCode, now()).isPresent()) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_FROZEN);
        }

        if (archiveRepository.existsByCode(normalizedDeviceCode)
                || archiveRequestRepository.hasPendingByTargetDeviceCode(normalizedDeviceCode)) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
        }

        OffsetDateTime submittedAt = now();
        Optional<List<ArchiveImage>> imageChange = archiveImageService.prepareChange(null, images);
        Map<String, ArchiveFieldChange> normalizedChanges = normalizeAndValidateCreateChanges(changes);
        String requestId = newRequestId();
        ArchiveRequest created = createRequest(new ArchiveRequestCreate(
                requestId,
                ArchiveRequestType.CREATE,
                null,
                normalizedDeviceCode,
                applicant.id(),
                "NEW",
                normalizeRequiredText(reason, "reason", 500),
                normalizedChanges,
                normalizeInitiatedAt(initiatedAt, submittedAt),
                submittedAt));
        imageChange.ifPresent(value -> archiveImageService.savePendingChange(requestId, value));
        logEntryService.recordSuccess(
                LogAction.ARCHIVE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted archive create request.");
        return created;
    }

    private ArchiveRequest createArchiveDeleteRequest(
            String deviceId,
            String reason,
            List<ArchiveImageSubmission> images,
            OffsetDateTime initiatedAt,
            AuthenticatedUser applicant) {
        if (images != null) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID, "Delete requests cannot change images.");
        }
        requirePermission(applicant, PermissionCode.ARCHIVE_CENTER_ARCHIVE_DELETE_REQUEST_SUBMIT);
        Archive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (archiveRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_LOCKED);
        }

        if (archiveRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()
                || DELETE_BLOCKING_STATUSES.contains(device.status())) {
            throw new BusinessException(ErrorCode.ARCHIVE_DELETE_BLOCKED);
        }

        ArchiveRequest created = createRequest(new ArchiveRequestCreate(
                newRequestId(),
                ArchiveRequestType.DELETE,
                device.id(),
                device.deviceCode(),
                applicant.id(),
                device.status(),
                normalizeRequiredText(reason, "reason", 500),
                buildDeleteSnapshot(device),
                normalizeInitiatedAt(initiatedAt, now),
                now));
        logEntryService.recordSuccess(
                LogAction.ARCHIVE_REQUEST,
                created.id(),
                created.deviceCode(),
                applicant,
                "Submitted archive delete request.");
        return created;
    }

    private ArchiveRequest createRequest(ArchiveRequestCreate request) {
        try {
            archiveRequestRepository.create(request);
        } catch (DataIntegrityViolationException exception) {
            throw createConstraintConflict(request);
        }

        return enrichApplicantName(archiveRequestRepository.findById(request.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
    }

    private void applyApprovedRequest(
            ArchiveRequest request,
            String reviewComment,
            AuthenticatedUser reviewer,
            OffsetDateTime reviewedAt) {
        switch (request.type()) {
            case UPDATE -> {
                Archive currentDevice = archiveRepository.findById(request.deviceId())
                        .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
                verifyApprovalBaseline(currentDevice, request.changes());
                ArchiveUpdate archiveUpdate = buildArchiveUpdate(currentDevice, request.changes(), reviewer.id(), reviewedAt);
                OffsetDateTime freezeUntil = reviewedAt.plus(ARCHIVE_REQUEST_FREEZE_DURATION);
                boolean reviewed = archiveRequestRepository.applyApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        freezeUntil,
                        archiveUpdate);
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
                archiveImageService.applyPendingChange(request.id(), currentDevice.id(), reviewer.id());
            }
            case CREATE -> {
                if (archiveRepository.existsByCode(request.deviceCode())) {
                    throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
                }

                ArchiveCreate archiveCreate = buildArchiveCreate(request, reviewer.id(), reviewedAt);
                try {
                    archiveRepository.create(archiveCreate);
                } catch (DataIntegrityViolationException exception) {
                    throw new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
                }
                qrCodeIssuer.issueInitial(
                        archiveCreate.id(),
                        archiveCreate.deviceCode(),
                        reviewedAt,
                        reviewer.id());

                boolean reviewed = archiveRequestRepository.markApprovedReview(
                        request.id(),
                        reviewer.id(),
                        reviewComment,
                        reviewedAt,
                        reviewedAt.plus(ARCHIVE_REQUEST_FREEZE_DURATION));
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
                archiveImageService.applyPendingChange(request.id(), archiveCreate.id(), reviewer.id());
            }
            case DELETE -> {
                Archive currentDevice = archiveRepository.findById(request.deviceId())
                        .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
                verifyApprovalBaseline(currentDevice, request.changes());
                if (DELETE_BLOCKING_STATUSES.contains(currentDevice.status())
                        || archiveRequestRepository.findActiveFreezeUntil(currentDevice.id(), reviewedAt).isPresent()) {
                    throw new BusinessException(ErrorCode.ARCHIVE_DELETE_BLOCKED);
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
                        reviewedAt.plus(ARCHIVE_REQUEST_FREEZE_DURATION));
                if (!reviewed) {
                    throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_ALREADY_REVIEWED);
                }
            }
        }
    }

    private void verifyApprovalBaseline(Archive currentDevice, Map<String, ArchiveFieldChange> changes) {
        for (Map.Entry<String, ArchiveFieldChange> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            ArchiveFieldChange value = requireChangeValue(entry.getValue());
            String expectedOldValue = normalizeText(value.oldValue());
            String currentValue = currentFieldValue(currentDevice, field);
            if (!expectedOldValue.equals(currentValue)) {
                throw new BusinessException(ErrorCode.CONFLICT, "Archive baseline changed before approval.");
            }
        }
    }

    private BusinessException createConstraintConflict(ArchiveRequestCreate request) {
        if (request.type() == ArchiveRequestType.CREATE) {
            return new BusinessException(ErrorCode.DEVICE_CODE_DUPLICATED);
        }

        return new BusinessException(ErrorCode.ARCHIVE_REQUEST_LOCKED);
    }

    private Map<String, ArchiveFieldChange> normalizeAndValidateUpdateChanges(
            Archive device,
            Map<String, ArchiveFieldChange> changes,
            boolean imageChangeRequested) {
        if (changes == null || changes.isEmpty()) {
            if (imageChangeRequested) {
                return Map.of();
            }
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
        }

        Map<String, ArchiveFieldChange> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, ArchiveFieldChange> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            ArchiveFieldChange value = requireChangeValue(entry.getValue());
            if (value.oldValue() == null) {
                throw new BusinessException(
                        ErrorCode.ARCHIVE_REQUEST_INVALID,
                        "oldValue is required when updating an archive.");
            }

            String currentValue = currentFieldValue(device, field);
            String oldValue = normalizeText(value.oldValue());
            String newValue = normalizeChangeValue(field, value.newValue(), isRequiredUpdateField(field));
            if (!oldValue.equals(currentValue)) {
                throw new BusinessException(ErrorCode.CONFLICT, "Archive baseline is stale.");
            }

            if (!newValue.equals(currentValue)) {
                normalizedChanges.put(field, new ArchiveFieldChange(currentValue, newValue));
            }
        }

        if (normalizedChanges.isEmpty() && !imageChangeRequested) {
            throw new BusinessException(
                    ErrorCode.ARCHIVE_REQUEST_INVALID,
                    "At least one archive field must change.");
        }

        return Map.copyOf(normalizedChanges);
    }

    private Map<String, ArchiveFieldChange> normalizeAndValidateCreateChanges(Map<String, ArchiveFieldChange> changes) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
        }

        Map<String, ArchiveFieldChange> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, ArchiveFieldChange> entry : changes.entrySet()) {
            String field = normalizeSupportedField(entry.getKey());
            ArchiveFieldChange value = requireChangeValue(entry.getValue());
            String newValue = normalizeChangeValue(field, value.newValue(), REQUIRED_CREATE_FIELDS.contains(field));
            if (!newValue.isBlank()) {
                normalizedChanges.put(field, new ArchiveFieldChange("", newValue));
            }
        }

        for (String field : REQUIRED_CREATE_FIELDS) {
            if (!normalizedChanges.containsKey(field)) {
                throw new BusinessException(
                        ErrorCode.ARCHIVE_REQUEST_INVALID,
                        field + " is required when creating an archive.");
            }
        }

        return Map.copyOf(normalizedChanges);
    }

    private boolean isRequiredUpdateField(String field) {
        return true;
    }

    private Map<String, ArchiveFieldChange> buildDeleteSnapshot(Archive device) {
        Map<String, ArchiveFieldChange> snapshot = new HashMap<>();
        snapshot.put("name", new ArchiveFieldChange(normalizeText(device.name()), ""));
        snapshot.put("deviceType", new ArchiveFieldChange(normalizeText(device.deviceType()), ""));
        snapshot.put("model", new ArchiveFieldChange(normalizeText(device.model()), ""));
        snapshot.put("manufacturer", new ArchiveFieldChange(normalizeText(device.manufacturer()), ""));
        snapshot.put("commissionedAt", new ArchiveFieldChange(formatDate(device.commissionedAt()), ""));
        snapshot.put("managementDepartment", new ArchiveFieldChange(normalizeText(device.managementDepartment()), ""));
        snapshot.put("location.address", new ArchiveFieldChange(normalizeText(device.address()), ""));
        return Map.copyOf(snapshot);
    }

    private ArchiveCreate buildArchiveCreate(ArchiveRequest request, String reviewerId, OffsetDateTime reviewedAt) {
        return new ArchiveCreate(
                "device-" + UUID.randomUUID(),
                request.deviceCode(),
                requireCreatedValue(request, "name"),
                requireCreatedValue(request, "deviceType"),
                requireCreatedValue(request, "model"),
                requireCreatedValue(request, "manufacturer"),
                parseCommissionedAt(requireCreatedValue(request, "commissionedAt")),
                requireCreatedValue(request, "managementDepartment"),
                "PENDING_VERIFICATION",
                requireCreatedValue(request, "location.address"),
                null,
                null,
                reviewerId,
                reviewedAt);
    }

    private ArchiveUpdate buildArchiveUpdate(
            Archive currentDevice,
            Map<String, ArchiveFieldChange> changes,
            String reviewerId,
            OffsetDateTime reviewedAt) {
        String name = currentDevice.name();
        String deviceType = currentDevice.deviceType();
        String model = currentDevice.model();
        String manufacturer = currentDevice.manufacturer();
        LocalDate commissionedAt = currentDevice.commissionedAt();
        String managementDepartment = currentDevice.managementDepartment();
        String address = currentDevice.address();

        for (Map.Entry<String, ArchiveFieldChange> entry : changes.entrySet()) {
            switch (entry.getKey()) {
                case "name" -> name = entry.getValue().newValue();
                case "deviceType" -> deviceType = entry.getValue().newValue();
                case "model" -> model = entry.getValue().newValue();
                case "manufacturer" -> manufacturer = entry.getValue().newValue();
                case "commissionedAt" -> commissionedAt = parseCommissionedAt(entry.getValue().newValue());
                case "managementDepartment" -> managementDepartment = entry.getValue().newValue();
                case "location.address" -> address = entry.getValue().newValue();
                default -> throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
            }
        }

        return new ArchiveUpdate(
                currentDevice.id(),
                name,
                deviceType,
                model,
                manufacturer,
                commissionedAt,
                managementDepartment,
                address,
                reviewerId,
                reviewedAt);
    }

    private String currentFieldValue(Archive device, String field) {
        return switch (field) {
            case "name" -> normalizeText(device.name());
            case "deviceType" -> normalizeText(device.deviceType());
            case "model" -> normalizeText(device.model());
            case "manufacturer" -> normalizeText(device.manufacturer());
            case "commissionedAt" -> formatDate(device.commissionedAt());
            case "managementDepartment" -> normalizeText(device.managementDepartment());
            case "location.address" -> normalizeText(device.address());
            default -> throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
        };
    }

    private String normalizeChangeValue(String field, String value, boolean required) {
        if ("commissionedAt".equals(field)) {
            String normalized = required
                    ? normalizeRequiredText(value, field, 10)
                    : normalizeOptionalText(value, 10);
            if (normalized.isBlank()) {
                return normalized;
            }

            return parseCommissionedAt(normalized).toString();
        }

        int maxLength = switch (field) {
            case "name", "model", "deviceType" -> 80;
            case "manufacturer" -> 100;
            case "managementDepartment" -> 120;
            case "location.address" -> 200;
            default -> throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
        };
        return required ? normalizeRequiredText(value, field, maxLength) : normalizeOptionalText(value, maxLength);
    }

    private LocalDate parseCommissionedAt(String value) {
        try {
            return LocalDate.parse(value);
        } catch (RuntimeException exception) {
            throw new BusinessException(
                    ErrorCode.ARCHIVE_REQUEST_INVALID,
                    "commissionedAt must be a valid date.");
        }
    }

    private String formatDate(LocalDate value) {
        return value == null ? "" : value.toString();
    }

    private String normalizeSupportedField(String field) {
        String normalized = field == null ? "" : field.trim();
        if (!SUPPORTED_FIELDS.contains(normalized)) {
            throw new BusinessException(
                    ErrorCode.ARCHIVE_REQUEST_INVALID,
                    "Unsupported archive request field: " + normalized);
        }

        return normalized;
    }

    private ArchiveFieldChange requireChangeValue(ArchiveFieldChange value) {
        if (value == null) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
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

    private String requireCreatedValue(ArchiveRequest request, String field) {
        String value = createdValue(request, field);
        if (value.isBlank()) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
        }

        return value;
    }

    private String createdValue(ArchiveRequest request, String field) {
        ArchiveFieldChange value = request.changes().get(field);
        return value == null ? "" : normalizeText(value.newValue());
    }

    private String normalizeRequiredText(String value, String field, int maxLength) {
        String normalized = normalizeOptionalText(value, maxLength);
        if (normalized.isBlank()) {
            throw new BusinessException(
                    ErrorCode.ARCHIVE_REQUEST_INVALID,
                    field + " is required and must not exceed " + maxLength + " characters.");
        }

        return normalized;
    }

    private String normalizeOptionalText(String value, int maxLength) {
        String normalized = normalizeText(value);
        if (normalized.length() > maxLength) {
            throw new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID);
        }

        return normalized;
    }

    private String normalizeText(String value) {
        return value == null ? "" : value.trim();
    }

    private OffsetDateTime normalizeInitiatedAt(OffsetDateTime initiatedAt, OffsetDateTime submittedAt) {
        return initiatedAt == null ? submittedAt : initiatedAt.withOffsetSameInstant(ZoneOffset.UTC);
    }

    private String normalizeLogTarget(String value) {
        String normalized = normalizeText(value);
        return normalized.isBlank() ? null : normalized;
    }

    private String resolveArchiveRequestTargetNo(String deviceId, String deviceCode) {
        String normalizedDeviceCode = normalizeLogTarget(deviceCode);
        if (normalizedDeviceCode != null) {
            return normalizedDeviceCode.toUpperCase();
        }

        String normalizedDeviceId = normalizeLogTarget(deviceId);
        if (normalizedDeviceId == null) {
            return null;
        }

        try {
            return archiveRepository.findById(normalizedDeviceId)
                    .map(Archive::deviceCode)
                    .orElse(normalizedDeviceId);
        } catch (RuntimeException exception) {
            return normalizedDeviceId;
        }
    }

    private String formatRequestType(ArchiveRequestType requestType) {
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

    private ArchiveRequestStatus parseStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }

        try {
            return ArchiveRequestStatus.valueOf(status.trim().toUpperCase());
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

    private ArchiveRequest enrichApplicantName(ArchiveRequest request) {
        String applicantName = userStore.findById(request.applicantId())
                .map(user -> user.displayName())
                .orElse(request.applicantId());
        return new ArchiveRequest(
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


