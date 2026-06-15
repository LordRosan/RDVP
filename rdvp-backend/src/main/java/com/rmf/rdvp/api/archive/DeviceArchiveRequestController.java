package com.rmf.rdvp.api.archive;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
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

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.archive.DeviceArchiveRequestPage;
import com.rmf.rdvp.archive.DeviceArchiveRequestService;
import com.rmf.rdvp.archive.DeviceArchiveReviewDecision;
import com.rmf.rdvp.archive.DeviceArchiveRequestType;
import com.rmf.rdvp.archive.DeviceArchiveFieldChange;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticationService;
import com.rmf.rdvp.identity.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/device-archive-requests")
public class DeviceArchiveRequestController {

    private final DeviceArchiveRequestService archiveRequestService;
    private final AuthenticationService authenticationService;
    private final AuditLogService auditLogService;

    public DeviceArchiveRequestController(
            DeviceArchiveRequestService archiveRequestService,
            AuthenticationService authenticationService,
            AuditLogService auditLogService) {
        this.archiveRequestService = archiveRequestService;
        this.authenticationService = authenticationService;
        this.auditLogService = auditLogService;
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
    @PreAuthorize("hasAuthority('MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW')")
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
    @PreAuthorize("hasAuthority('MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW')")
    public ResponseEntity<ApiResponse<DeviceArchiveReviewResultResponse>> review(
            @PathVariable String requestId,
            @Valid @RequestBody ReviewDeviceArchiveRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var reviewed = archiveRequestService.review(
                requestId,
                parseDecision(requestBody.decision()),
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
        String targetId = normalizeAuditText(deviceId);
        String targetNo = normalizeAuditText(deviceCode);
        if (targetNo.isBlank()) {
            targetNo = targetId;
        }

        auditLogService.recordFailure(
                AuditAction.DEVICE_ARCHIVE_REQUEST,
                targetId,
                targetNo,
                user,
                "设备档案删除申请提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private String normalizeAuditText(String value) {
        return value == null ? "" : value.trim();
    }

    private OffsetDateTime parseInitiatedAt(String initiatedAt) {
        if (initiatedAt == null || initiatedAt.isBlank()) {
            return null;
        }

        try {
            return OffsetDateTime.parse(initiatedAt.trim()).withOffsetSameInstant(ZoneOffset.UTC);
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "initiatedAt is invalid.");
        }
    }
}


