package com.rmf.rdvp.archive;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.BootstrapUserStore;

@Service
public class DeviceChangeRequestService {

    private static final Duration CHANGE_FREEZE_DURATION = Duration.ofHours(12);
    private static final Pattern REQUEST_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final Set<String> SUPPORTED_FIELDS = Set.of("name", "model", "manufacturer", "location.address");

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceChangeRequestRepository changeRequestRepository;
    private final BootstrapUserStore userStore;

    public DeviceChangeRequestService(
            DeviceArchiveRepository archiveRepository,
            DeviceChangeRequestRepository changeRequestRepository,
            BootstrapUserStore userStore) {
        this.archiveRepository = archiveRepository;
        this.changeRequestRepository = changeRequestRepository;
        this.userStore = userStore;
    }

    @Transactional
    public DeviceChangeRequest create(
            String deviceId,
            String reason,
            Map<String, DeviceChangeValue> changes,
            AuthenticatedUser applicant) {
        DeviceArchive device = archiveRepository.findById(normalizeRequiredId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        OffsetDateTime now = now();

        if (changeRequestRepository.hasPendingByDeviceId(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_LOCKED);
        }

        if (changeRequestRepository.findActiveFreezeUntil(device.id(), now).isPresent()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_FROZEN);
        }

        Map<String, DeviceChangeValue> normalizedChanges = normalizeAndValidateChanges(device, changes);
        String normalizedReason = normalizeRequiredText(reason, "reason", 500);
        String requestId = "DCR-" + UUID.randomUUID();
        changeRequestRepository.create(new DeviceChangeRequestCreate(
                requestId,
                device.id(),
                applicant.id(),
                device.status(),
                normalizedReason,
                normalizedChanges,
                now));
        return enrichApplicantName(changeRequestRepository.findById(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
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
            String reviewComment,
            AuthenticatedUser reviewer) {
        String normalizedRequestId = normalizeRequiredId(requestId, "requestId");
        DeviceChangeRequest request = changeRequestRepository.findById(normalizedRequestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.CHANGE_REQUEST_NOT_FOUND));

        if (request.status() != DeviceChangeRequestStatus.PENDING_REVIEW) {
            throw new BusinessException(ErrorCode.CHANGE_REQUEST_ALREADY_REVIEWED);
        }

        OffsetDateTime reviewedAt = now();
        String normalizedComment = reviewComment == null ? "" : reviewComment.trim();
        if (decision == DeviceChangeReviewDecision.REJECTED && normalizedComment.isBlank()) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    "Review comment is required when rejecting a change request.");
        }

        if (decision == DeviceChangeReviewDecision.APPROVED) {
            DeviceArchive currentDevice = archiveRepository.findById(request.deviceId())
                    .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
            DeviceArchiveUpdate archiveUpdate = buildArchiveUpdate(currentDevice, request.changes(), reviewer.id(), reviewedAt);
            OffsetDateTime freezeUntil = reviewedAt.plus(CHANGE_FREEZE_DURATION);
            changeRequestRepository.applyApprovedReview(
                    request.id(),
                    reviewer.id(),
                    normalizedComment,
                    reviewedAt,
                    freezeUntil,
                    archiveUpdate);
        } else {
            changeRequestRepository.applyRejectedReview(request.id(), reviewer.id(), normalizedComment, reviewedAt);
        }

        return enrichApplicantName(changeRequestRepository.findById(request.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR)));
    }

    private Map<String, DeviceChangeValue> normalizeAndValidateChanges(
            DeviceArchive device,
            Map<String, DeviceChangeValue> changes) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        }

        Map<String, DeviceChangeValue> normalizedChanges = new HashMap<>();
        for (Map.Entry<String, DeviceChangeValue> entry : changes.entrySet()) {
            String field = entry.getKey() == null ? "" : entry.getKey().trim();
            if (!SUPPORTED_FIELDS.contains(field)) {
                throw new BusinessException(
                        ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                        "Unsupported archive change field: " + field);
            }

            DeviceChangeValue value = entry.getValue();
            if (value == null) {
                throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
            }

            String currentValue = currentFieldValue(device, field);
            String oldValue = normalizeText(value.oldValue());
            String newValue = normalizeChangeValue(field, value.newValue());
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

    private String normalizeChangeValue(String field, String value) {
        int maxLength = switch (field) {
            case "name", "model" -> 80;
            case "manufacturer" -> 100;
            case "location.address" -> 200;
            default -> throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        };
        return normalizeRequiredText(value, field, maxLength);
    }

    private String normalizeRequiredText(String value, String field, int maxLength) {
        String normalized = normalizeText(value);
        if (normalized.isBlank() || normalized.length() > maxLength) {
            throw new BusinessException(
                    ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                    field + " is required and must not exceed " + maxLength + " characters.");
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

    private int normalizePage(int page) {
        return Math.max(page, 1);
    }

    private int normalizePageSize(int pageSize) {
        if (pageSize <= 0) {
            return 20;
        }

        return Math.min(pageSize, 100);
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
