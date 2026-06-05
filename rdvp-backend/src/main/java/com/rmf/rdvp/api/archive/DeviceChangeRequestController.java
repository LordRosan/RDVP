package com.rmf.rdvp.api.archive;

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
import com.rmf.rdvp.archive.DeviceChangeRequestPage;
import com.rmf.rdvp.archive.DeviceChangeRequestService;
import com.rmf.rdvp.archive.DeviceChangeReviewDecision;
import com.rmf.rdvp.archive.DeviceChangeRequestType;
import com.rmf.rdvp.archive.DeviceChangeValue;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/device-change-requests")
public class DeviceChangeRequestController {

    private final DeviceChangeRequestService changeRequestService;

    public DeviceChangeRequestController(DeviceChangeRequestService changeRequestService) {
        this.changeRequestService = changeRequestService;
    }

    @PostMapping
    @PreAuthorize("hasAnyAuthority('ARCHIVE_CHANGE_REQUEST_CREATE','ARCHIVE_DEVICE_CREATE','ARCHIVE_DEVICE_DELETE')")
    public ResponseEntity<ApiResponse<DeviceChangeCreateResponse>> create(
            @Valid @RequestBody CreateDeviceChangeRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var created = changeRequestService.create(
                parseType(requestBody.type()),
                requestBody.deviceId(),
                requestBody.deviceCode(),
                requestBody.reason(),
                toDomainChanges(requestBody.changes()),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceChangeCreateResponse.from(created), RequestIds.resolve(request)));
    }

    @GetMapping
    @PreAuthorize("hasAuthority('MGMT_ARCHIVE_CHANGE_REVIEW')")
    public ResponseEntity<ApiResponse<DeviceChangeReviewListResponse>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String deviceCode,
            @RequestParam(required = false) String applicantId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            HttpServletRequest request) {
        DeviceChangeRequestPage result = changeRequestService.list(status, deviceCode, applicantId, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(DeviceChangeReviewListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/{requestId}/review")
    @PreAuthorize("hasAuthority('MGMT_ARCHIVE_CHANGE_REVIEW')")
    public ResponseEntity<ApiResponse<DeviceChangeReviewResultResponse>> review(
            @PathVariable String requestId,
            @Valid @RequestBody ReviewDeviceChangeRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var reviewed = changeRequestService.review(
                requestId,
                parseDecision(requestBody.decision()),
                requestBody.reviewedAt(),
                requestBody.reviewComment(),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceChangeReviewResultResponse.from(reviewed), RequestIds.resolve(request)));
    }

    private Map<String, DeviceChangeValue> toDomainChanges(Map<String, DeviceChangeValueRequest> changes) {
        if (changes == null) {
            return Map.of();
        }

        return changes.entrySet()
                .stream()
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        entry -> {
                            DeviceChangeValueRequest value = entry.getValue();
                            return new DeviceChangeValue(
                                    value == null ? null : value.oldValue(),
                                    value == null ? null : value.newValue());
                        }));
    }

    private DeviceChangeRequestType parseType(String type) {
        if (type == null || type.isBlank()) {
            return DeviceChangeRequestType.UPDATE;
        }

        try {
            return DeviceChangeRequestType.valueOf(type.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "type is invalid.");
        }
    }

    private DeviceChangeReviewDecision parseDecision(String decision) {
        try {
            return DeviceChangeReviewDecision.valueOf(decision.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "decision is invalid.");
        }
    }
}
