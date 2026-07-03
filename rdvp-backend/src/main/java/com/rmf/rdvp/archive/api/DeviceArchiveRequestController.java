package com.rmf.rdvp.archive.api;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.archive.DeviceArchiveRequestPage;
import com.rmf.rdvp.archive.DeviceArchiveRequestService;
import com.rmf.rdvp.archive.DeviceArchiveReviewDecision;
import com.rmf.rdvp.archive.DeviceArchiveRequestType;
import com.rmf.rdvp.archive.DeviceArchiveFieldChange;
import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryService;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticationService;
import com.rmf.rdvp.user.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/device-archive-requests")
public class DeviceArchiveRequestController {

    private static final DateTimeFormatter LOCAL_DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    private final DeviceArchiveRequestService archiveRequestService;
    private final AuthenticationService authenticationService;
    private final LogEntryService logEntryService;

    public DeviceArchiveRequestController(
            DeviceArchiveRequestService archiveRequestService,
            AuthenticationService authenticationService,
            LogEntryService logEntryService) {
        this.archiveRequestService = archiveRequestService;
        this.authenticationService = authenticationService;
        this.logEntryService = logEntryService;
    }

    @PostMapping
    @PreAuthorize("hasAnyAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT','ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT','ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT')")
    public ResponseEntity<ApiResponse<DeviceArchiveRequestCreateResponse>> create(
            @Valid @RequestBody CreateDeviceArchiveRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        DeviceArchiveRequestType requestType = parseType(requestBody.type());
        if (requestType == DeviceArchiveRequestType.DELETE) {
            try {
                authenticationService.requireRecentPasswordVerification(user);
            } catch (BusinessException exception) {
                recordDeleteRequestVerificationFailure(requestBody.deviceId(), requestBody.deviceCode(), user, exception);
                throw exception;
            }
        }

        var created = archiveRequestService.create(
                requestType,
                requestBody.deviceId(),
                requestBody.deviceCode(),
                requestBody.reason(),
                toDomainChanges(requestBody.changes()),
                parseInitiatedAt(requestBody.initiatedAt()),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceArchiveRequestCreateResponse.from(created), RequestIds.resolve(request)));
    }

    @GetMapping
    @PreAuthorize("hasAuthority('REVIEW_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW')")
    public ResponseEntity<ApiResponse<DeviceArchiveReviewListResponse>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String deviceCode,
            @RequestParam(required = false) String applicantId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            HttpServletRequest request) {
        DeviceArchiveRequestPage result = archiveRequestService.list(status, deviceCode, applicantId, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(DeviceArchiveReviewListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/{requestId}/review")
    @PreAuthorize("hasAuthority('REVIEW_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW')")
    public ResponseEntity<ApiResponse<DeviceArchiveReviewResultResponse>> review(
            @PathVariable String requestId,
            @Valid @RequestBody ReviewDeviceArchiveRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        DeviceArchiveReviewDecision decision = parseDecision(requestBody.decision());
        authenticationService.consumeRecentPasswordVerification(user);
        var reviewed = archiveRequestService.review(
                requestId,
                decision,
                requestBody.reviewedAt(),
                requestBody.reviewComment(),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceArchiveReviewResultResponse.from(reviewed), RequestIds.resolve(request)));
    }

    private Map<String, DeviceArchiveFieldChange> toDomainChanges(Map<String, DeviceArchiveFieldChangePayload> changes) {
        if (changes == null) {
            return Map.of();
        }

        return changes.entrySet()
                .stream()
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        entry -> {
                            DeviceArchiveFieldChangePayload value = entry.getValue();
                            return new DeviceArchiveFieldChange(
                                    value == null ? null : value.oldValue(),
                                    value == null ? null : value.newValue());
                        }));
    }

    private DeviceArchiveRequestType parseType(String type) {
        if (type == null || type.isBlank()) {
            return DeviceArchiveRequestType.UPDATE;
        }

        try {
            return DeviceArchiveRequestType.valueOf(type.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "type is invalid.");
        }
    }

    private DeviceArchiveReviewDecision parseDecision(String decision) {
        try {
            return DeviceArchiveReviewDecision.valueOf(decision.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "decision is invalid.");
        }
    }

    private void recordDeleteRequestVerificationFailure(
            String deviceId,
            String deviceCode,
            AuthenticatedUser user,
            BusinessException exception) {
        String targetId = normalizeLogText(deviceId);
        String targetNo = normalizeLogText(deviceCode);
        if (targetNo.isBlank()) {
            targetNo = targetId;
        }

        logEntryService.recordFailure(
                LogAction.DEVICE_ARCHIVE_REQUEST,
                targetId,
                targetNo,
                user,
                "设备档案删除申请提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private String normalizeLogText(String value) {
        return value == null ? "" : value.trim();
    }

    private OffsetDateTime parseInitiatedAt(String initiatedAt) {
        if (initiatedAt == null || initiatedAt.isBlank()) {
            return null;
        }

        String normalized = initiatedAt.trim();
        try {
            return OffsetDateTime.parse(normalized).withOffsetSameInstant(ZoneOffset.UTC);
        } catch (DateTimeParseException ignored) {
        }

        try {
            return LocalDateTime.parse(normalized, LOCAL_DATE_TIME_FORMATTER).atOffset(ZoneOffset.UTC);
        } catch (DateTimeParseException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "申请发起时间格式无效，请重新选择时间。");
        }
    }
}


