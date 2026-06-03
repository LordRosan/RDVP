package com.rmf.rdvp.api.archive;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.archive.DeviceArchiveService;
import com.rmf.rdvp.archive.DeviceVerificationResult;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class DeviceVerificationController {

    private final DeviceArchiveService archiveService;

    public DeviceVerificationController(DeviceArchiveService archiveService) {
        this.archiveService = archiveService;
    }

    @PostMapping("/devices/{deviceId}/verification-records")
    @PreAuthorize("hasAuthority('OPS_DEVICE_VERIFY')")
    public ResponseEntity<ApiResponse<DeviceVerificationRecordResponse>> createVerificationRecord(
            @PathVariable String deviceId,
            @Valid @RequestBody CreateDeviceVerificationRecordRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var record = archiveService.createVerificationRecord(
                deviceId,
                parseResult(requestBody.result()),
                requestBody.description(),
                requestBody.remark(),
                requestBody.verifiedAt(),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceVerificationRecordResponse.from(record), RequestIds.resolve(request)));
    }

    private DeviceVerificationResult parseResult(String value) {
        try {
            return DeviceVerificationResult.valueOf(value.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "result is invalid.");
        }
    }
}
