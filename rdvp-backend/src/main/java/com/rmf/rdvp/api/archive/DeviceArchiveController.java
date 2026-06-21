package com.rmf.rdvp.api.archive;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.archive.DeviceArchiveRequestService;
import com.rmf.rdvp.archive.DeviceArchiveService;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.AuthenticationService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
@PreAuthorize("hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY')")
public class DeviceArchiveController {

    private final DeviceArchiveService archiveService;
    private final DeviceArchiveRequestService archiveRequestService;
    private final AuthenticationService authenticationService;
    private final AuditLogService auditLogService;

    public DeviceArchiveController(
            DeviceArchiveService archiveService,
            DeviceArchiveRequestService archiveRequestService,
            AuthenticationService authenticationService,
            AuditLogService auditLogService) {
        this.archiveService = archiveService;
        this.archiveRequestService = archiveRequestService;
        this.authenticationService = authenticationService;
        this.auditLogService = auditLogService;
    }

    @GetMapping("/devices/by-code/{deviceCode}")
    public ResponseEntity<ApiResponse<DeviceArchiveResponse>> findByCode(
            @PathVariable String deviceCode,
            Authentication authentication,
            HttpServletRequest request) {
        DeviceArchiveResponse response = DeviceArchiveResponse.from(archiveService.findByCode(deviceCode));
        recordArchiveQuery(response, requireUser(authentication));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @GetMapping("/devices/{deviceId}")
    public ResponseEntity<ApiResponse<DeviceArchiveResponse>> findById(
            @PathVariable String deviceId,
            Authentication authentication,
            HttpServletRequest request) {
        DeviceArchiveResponse response = DeviceArchiveResponse.from(archiveService.findById(deviceId));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @GetMapping("/device-codes/{deviceCode}/availability")
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT')")
    public ResponseEntity<ApiResponse<DeviceCodeAvailabilityResponse>> checkDeviceCodeAvailability(
            @PathVariable String deviceCode,
            HttpServletRequest request) {
        if (archiveService.existsByCode(deviceCode)) {
            return ResponseEntity.ok(ApiResponse.success(
                    new DeviceCodeAvailabilityResponse(false, "设备编号已被现有档案使用"),
                    RequestIds.resolve(request)));
        }

        if (archiveRequestService.hasPendingCreateRequestByDeviceCode(deviceCode)) {
            return ResponseEntity.ok(ApiResponse.success(
                    new DeviceCodeAvailabilityResponse(false, "设备编号已有待审核的添加申请"),
                    RequestIds.resolve(request)));
        }

        return ResponseEntity.ok(ApiResponse.success(
                new DeviceCodeAvailabilityResponse(true, "设备编号可用于添加档案"),
                RequestIds.resolve(request)));
    }

    @PostMapping("/device-qrcodes/verify")
    public ResponseEntity<ApiResponse<QrVerificationResponse>> verifyQrCode(
            @Valid @RequestBody QrVerifyRequest requestBody,
            Authentication authentication,
            HttpServletRequest request) {
        QrVerificationResponse response = QrVerificationResponse.from(archiveService.verifyQrCode(requestBody.qrContent()));
        recordArchiveQuery(response.device(), requireUser(authentication));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @PostMapping("/devices/{deviceId}/qrcode-export")
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY') and hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT')")
    public ResponseEntity<ApiResponse<DeviceQrCodeExportResponse>> exportQrCode(
            @PathVariable String deviceId,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser operator = requireUser(authentication);
        authenticationService.consumeRecentPasswordVerification(operator);
        DeviceQrCodeExportResponse response = DeviceQrCodeExportResponse.from(archiveService.exportQrCode(deviceId, operator));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @PostMapping("/devices/{deviceId}/archive-export-verification")
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY') and hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT')")
    public ResponseEntity<ApiResponse<DeviceArchiveExportVerificationResponse>> verifyArchiveDetailExport(
            @PathVariable String deviceId,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser operator = requireUser(authentication);
        DeviceArchiveResponse archive = null;
        authenticationService.consumeRecentPasswordVerification(operator);

        try {
            archive = DeviceArchiveResponse.from(archiveService.findById(deviceId));
            auditLogService.recordSuccess(
                    AuditAction.DEVICE_ARCHIVE_EXPORT,
                    archive.id(),
                    archive.deviceCode(),
                    operator,
                    "导出设备档案详情。");
            DeviceArchiveExportVerificationResponse response = new DeviceArchiveExportVerificationResponse(
                    true,
                    archive.id(),
                    archive.deviceCode());
            return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
        } catch (BusinessException exception) {
            auditLogService.recordFailure(
                    AuditAction.DEVICE_ARCHIVE_EXPORT,
                    archive == null ? normalizeAuditTarget(deviceId) : archive.id(),
                    archive == null ? normalizeAuditTarget(deviceId) : archive.deviceCode(),
                    operator,
                    "设备档案详情导出失败：%s。".formatted(exception.getErrorCode().code()));
            throw exception;
        }
    }

    private AuthenticatedUser requireUser(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser user)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }

        return user;
    }

    private void recordArchiveQuery(DeviceArchiveResponse response, AuthenticatedUser operator) {
        auditLogService.recordSuccess(
                AuditAction.DEVICE_ARCHIVE_QUERY,
                response.id(),
                response.deviceCode(),
                operator,
                "查询设备档案。");
    }

    private String normalizeAuditTarget(String value) {
        String normalized = value == null ? "" : value.trim();
        return normalized.isBlank() ? null : normalized;
    }
}


