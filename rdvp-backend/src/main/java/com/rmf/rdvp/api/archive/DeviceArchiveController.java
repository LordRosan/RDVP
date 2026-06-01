package com.rmf.rdvp.api.archive;

import org.springframework.http.ResponseEntity;
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

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
@PreAuthorize("hasAuthority('ARCHIVE_DEVICE_READ')")
public class DeviceArchiveController {

    private final DeviceArchiveService archiveService;

    public DeviceArchiveController(DeviceArchiveService archiveService) {
        this.archiveService = archiveService;
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
}
