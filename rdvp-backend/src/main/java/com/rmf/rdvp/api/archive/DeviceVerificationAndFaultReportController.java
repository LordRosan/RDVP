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
import com.rmf.rdvp.identity.AuthenticationService;
import com.rmf.rdvp.operations.FaultSeverity;
import com.rmf.rdvp.operations.FaultType;
import com.rmf.rdvp.operations.OperationsService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class DeviceVerificationAndFaultReportController {

    private final DeviceArchiveService archiveService;
    private final OperationsService operationsService;
    private final AuthenticationService authenticationService;

    public DeviceVerificationAndFaultReportController(
            DeviceArchiveService archiveService,
            OperationsService operationsService,
            AuthenticationService authenticationService) {
        this.archiveService = archiveService;
        this.operationsService = operationsService;
        this.authenticationService = authenticationService;
    }

    @PostMapping("/devices/{deviceId}/verification-records")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT')")
    public ResponseEntity<ApiResponse<DeviceVerificationRecordResponse>> createVerificationRecord(
            @PathVariable String deviceId,
            @Valid @RequestBody CreateDeviceVerificationRecordRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        authenticationService.consumeRecentPasswordVerification(user);
        var record = archiveService.createVerificationRecord(
                deviceId,
                parseResult(requestBody.result()),
                requestBody.description(),
                requestBody.remark(),
                requestBody.verifiedAt(),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceVerificationRecordResponse.from(record), RequestIds.resolve(request)));
    }

    @PostMapping("/devices/{deviceId}/verification-records/fault-report")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT') and hasAuthority('OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT')")
    public ResponseEntity<ApiResponse<DeviceVerificationAndFaultReportResponse>> createVerificationAndFaultReport(
            @PathVariable String deviceId,
            @Valid @RequestBody CreateDeviceVerificationAndFaultReportRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        authenticationService.consumeRecentPasswordVerification(user);
        var result = operationsService.createVerificationAndFaultReport(
                deviceId,
                parseEnum(DeviceVerificationResult.class, requestBody.result(), "result"),
                requestBody.description(),
                requestBody.remark(),
                requestBody.verifiedAt(),
                parseEnum(FaultType.class, requestBody.faultType(), "faultType"),
                parseEnum(FaultSeverity.class, requestBody.severity(), "severity"),
                requestBody.occurredAt(),
                requestBody.faultDescription(),
                requestBody.sceneCondition(),
                requestBody.longitude(),
                requestBody.latitude(),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceVerificationAndFaultReportResponse.from(result), RequestIds.resolve(request)));
    }

    private DeviceVerificationResult parseResult(String value) {
        return parseEnum(DeviceVerificationResult.class, value, "result");
    }

    private <T extends Enum<T>> T parseEnum(Class<T> enumType, String value, String field) {
        try {
            return Enum.valueOf(enumType, value.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }
}


