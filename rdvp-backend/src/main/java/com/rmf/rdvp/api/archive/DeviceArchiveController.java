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
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.AuthenticationService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
@PreAuthorize("hasAuthority('ARCHIVE_DEVICE_READ')")
public class DeviceArchiveController {

    private final DeviceArchiveService archiveService;
    private final AuthenticationService authenticationService;

    public DeviceArchiveController(DeviceArchiveService archiveService, AuthenticationService authenticationService) {
        this.archiveService = archiveService;
        this.authenticationService = authenticationService;
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
    @PreAuthorize("hasAuthority('ARCHIVE_QRCODE_EXPORT')")
    public ResponseEntity<ApiResponse<DeviceQrCodeExportResponse>> exportQrCode(
            @PathVariable String deviceId,
            @Valid @RequestBody DeviceQrCodeExportRequest requestBody,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser operator = requireUser(authentication);
        if (!authenticationService.verifyPassword(operator, requestBody.password())) {
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
}
