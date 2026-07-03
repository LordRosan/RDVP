package com.rmf.rdvp.archive.api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.archive.ArchiveRequestService;
import com.rmf.rdvp.archive.ArchiveService;
import com.rmf.rdvp.log.LogAction;
import com.rmf.rdvp.log.LogEntryService;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticatedUser;
import com.rmf.rdvp.user.AuthenticationService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
@PreAuthorize("hasAuthority('ARCHIVE_CENTER_ARCHIVE_QUERY')")
public class ArchiveController {

    private final ArchiveService archiveService;
    private final ArchiveRequestService archiveRequestService;
    private final AuthenticationService authenticationService;
    private final LogEntryService logEntryService;

    public ArchiveController(
            ArchiveService archiveService,
            ArchiveRequestService archiveRequestService,
            AuthenticationService authenticationService,
            LogEntryService logEntryService) {
        this.archiveService = archiveService;
        this.archiveRequestService = archiveRequestService;
        this.authenticationService = authenticationService;
        this.logEntryService = logEntryService;
    }

    @GetMapping("/devices/by-code/{deviceCode}")
    public ResponseEntity<ApiResponse<ArchiveResponse>> findByCode(
            @PathVariable String deviceCode,
            Authentication authentication,
            HttpServletRequest request) {
        ArchiveResponse response = ArchiveResponse.from(archiveService.findByCode(deviceCode));
        recordArchiveQuery(response, requireUser(authentication));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @GetMapping("/devices/{deviceId}")
    public ResponseEntity<ApiResponse<ArchiveResponse>> findById(
            @PathVariable String deviceId,
            Authentication authentication,
            HttpServletRequest request) {
        ArchiveResponse response = ArchiveResponse.from(archiveService.findById(deviceId));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }

    @GetMapping("/device-codes/{deviceCode}/availability")
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_ARCHIVE_CREATE_REQUEST_SUBMIT')")
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
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_ARCHIVE_QUERY') and hasAuthority('ARCHIVE_CENTER_ARCHIVE_EXPORT')")
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
    @PreAuthorize("hasAuthority('ARCHIVE_CENTER_ARCHIVE_QUERY') and hasAuthority('ARCHIVE_CENTER_ARCHIVE_EXPORT')")
    public ResponseEntity<ApiResponse<ArchiveExportVerificationResponse>> verifyArchiveDetailExport(
            @PathVariable String deviceId,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser operator = requireUser(authentication);
        ArchiveResponse archive = null;
        authenticationService.consumeRecentPasswordVerification(operator);

        try {
            archive = ArchiveResponse.from(archiveService.findById(deviceId));
            logEntryService.recordSuccess(
                    LogAction.ARCHIVE_EXPORT,
                    archive.id(),
                    archive.deviceCode(),
                    operator,
                    "导出档案详情。");
            ArchiveExportVerificationResponse response = new ArchiveExportVerificationResponse(
                    true,
                    archive.id(),
                    archive.deviceCode());
            return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
        } catch (BusinessException exception) {
            logEntryService.recordFailure(
                    LogAction.ARCHIVE_EXPORT,
                    archive == null ? normalizeLogTarget(deviceId) : archive.id(),
                    archive == null ? normalizeLogTarget(deviceId) : archive.deviceCode(),
                    operator,
                    "档案详情导出失败：%s。".formatted(exception.getErrorCode().code()));
            throw exception;
        }
    }

    private AuthenticatedUser requireUser(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser user)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }

        return user;
    }

    private void recordArchiveQuery(ArchiveResponse response, AuthenticatedUser operator) {
        logEntryService.recordSuccess(
                LogAction.ARCHIVE_QUERY,
                response.id(),
                response.deviceCode(),
                operator,
                "查询档案。");
    }

    private String normalizeLogTarget(String value) {
        String normalized = value == null ? "" : value.trim();
        return normalized.isBlank() ? null : normalized;
    }
}


