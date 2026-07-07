package com.rmf.rdvp.operations.api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.operations.DeviceVerificationReportItem;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticatedUser;
import com.rmf.rdvp.user.AuthenticationService;
import com.rmf.rdvp.operations.FaultSeverity;
import com.rmf.rdvp.operations.FaultType;
import com.rmf.rdvp.operations.OperationsService;
import com.rmf.rdvp.operations.VerificationDeviceStatus;
import com.rmf.rdvp.operations.VerificationItemResult;
import com.rmf.rdvp.operations.VerificationMethod;
import com.rmf.rdvp.operations.VerificationType;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class VerificationReportController {

    private final OperationsService operationsService;
    private final AuthenticationService authenticationService;

    public VerificationReportController(
            OperationsService operationsService,
            AuthenticationService authenticationService) {
        this.operationsService = operationsService;
        this.authenticationService = authenticationService;
    }

    @PostMapping("/devices/{deviceId}/verification-reports")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT')")
    public ResponseEntity<ApiResponse<DeviceVerificationReportResponse>> createVerificationReport(
            @PathVariable String deviceId,
            @Valid @RequestBody CreateDeviceVerificationReportRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        authenticationService.consumeRecentPasswordVerification(user);
        var report = operationsService.createVerificationReport(
                deviceId,
                parseEnum(VerificationType.class, requestBody.verificationType(), "verificationType"),
                parseEnum(VerificationDeviceStatus.class, requestBody.deviceStatus(), "deviceStatus"),
                parseEnum(VerificationMethod.class, requestBody.verificationMethod(), "verificationMethod"),
                parseVerificationItems(requestBody.items()),
                requestBody.description(),
                requestBody.remark(),
                requestBody.verifiedAt(),
                user);
        return ResponseEntity.ok(ApiResponse.success(DeviceVerificationReportResponse.from(report), RequestIds.resolve(request)));
    }

    @PostMapping("/devices/{deviceId}/verification-reports/fault-report")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT') and hasAuthority('OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT')")
    public ResponseEntity<ApiResponse<AbnormalVerificationSubmissionResponse>> createAbnormalVerificationSubmission(
            @PathVariable String deviceId,
            @Valid @RequestBody CreateAbnormalVerificationSubmissionRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        authenticationService.consumeRecentPasswordVerification(user);
        var result = operationsService.createAbnormalVerificationSubmission(
                deviceId,
                parseEnum(VerificationType.class, requestBody.verificationType(), "verificationType"),
                parseEnum(VerificationDeviceStatus.class, requestBody.deviceStatus(), "deviceStatus"),
                parseEnum(VerificationMethod.class, requestBody.verificationMethod(), "verificationMethod"),
                parseVerificationItems(requestBody.items()),
                requestBody.description(),
                requestBody.remark(),
                requestBody.verifiedAt(),
                parseEnum(FaultType.class, requestBody.faultType(), "faultType"),
                requestBody.faultSubtype(),
                parseEnum(FaultSeverity.class, requestBody.severity(), "severity"),
                requestBody.occurredAt(),
                requestBody.faultDescription(),
                requestBody.sceneCondition(),
                requestBody.longitude(),
                requestBody.latitude(),
                user);
        return ResponseEntity.ok(ApiResponse.success(AbnormalVerificationSubmissionResponse.from(result), RequestIds.resolve(request)));
    }

    private java.util.List<DeviceVerificationReportItem> parseVerificationItems(
            java.util.List<DeviceVerificationReportItemRequest> items) {
        return items.stream()
                .map(item -> new DeviceVerificationReportItem(
                        item.itemCode(),
                        item.itemName(),
                        parseEnum(VerificationItemResult.class, item.result(), "item.result"),
                        0))
                .toList();
    }

    private <T extends Enum<T>> T parseEnum(Class<T> enumType, String value, String field) {
        try {
            return Enum.valueOf(enumType, value.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }
}
