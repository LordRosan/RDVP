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
    private final AuthenticationService authenticationService;
    private final AuditLogService auditLogService;

    public DeviceArchiveController(
            DeviceArchiveService archiveService,
            AuthenticationService authenticationService,
            AuditLogService auditLogService) {
        this.archiveService = archiveService;
        this.authenticationService = authenticationService;
        this.auditLogService = auditLogService;
    }

    @GetMapping("/devices/by-code/{deviceCode}")
    public ResponseEntity<ApiResponse<DeviceArchiveResponse>> findByCode(
            @PathVariable String deviceCode,
            HttpServletRequest request) {
        DeviceArchiveResponse response = DeviceArchiveResponse.from(archiveService.findByCode(deviceCode));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @GetMapping("/devices/{deviceId}")
    public ResponseEntity<ApiResponse<DeviceArchiveResponse>> findById(
            @PathVariable String deviceId,
            HttpServletRequest request) {
        DeviceArchiveResponse response = DeviceArchiveResponse.from(archiveService.findById(deviceId));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @PostMapping("/device-qrcodes/verify")
    public ResponseEntity<ApiResponse<QrVerificationResponse>> verifyQrCode(
            @Valid @RequestBody QrVerifyRequest requestBody,
            HttpServletRequest request) {
        QrVerificationResponse response = QrVerificationResponse.from(archiveService.verifyQrCode(requestBody.qrContent()));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @PostMapping("/devices/{deviceId}/qrcode-export")
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY') and hasAuthority('ARCHIVE_CENTER_DEVICE_ARCHIVE_QR_CODE_EXPORT')")
    public ResponseEntity<ApiResponse<DeviceQrCodeExportResponse>> exportQrCode(
            @PathVariable String deviceId,
            @Valid @RequestBody DeviceQrCodeExportRequest requestBody,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser operator = requireUser(authentication);
        boolean verified;
        try {
            verified = authenticationService.verifyPassword(operator, requestBody.password());
        } catch (BusinessException exception) {
            recordQrCodeExportVerificationFailure(deviceId, operator, exception.getErrorCode());
            throw exception;
        }

        if (!verified) {
            recordQrCodeExportVerificationFailure(deviceId, operator, ErrorCode.INVALID_CREDENTIALS);
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }

        DeviceQrCodeExportResponse response = DeviceQrCodeExportResponse.from(archiveService.exportQrCode(deviceId, operator));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    private AuthenticatedUser requireUser(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser user)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }

        return user;
    }

    private void recordQrCodeExportVerificationFailure(
            String deviceId,
            AuthenticatedUser operator,
            ErrorCode errorCode) {
        String target = deviceId == null ? "" : deviceId.trim();
        auditLogService.recordFailure(
                AuditAction.DEVICE_QRCODE_EXPORT,
                target,
                target,
                operator,
                "设备二维码导出失败：%s。".formatted(errorCode.code()));
    }
}


