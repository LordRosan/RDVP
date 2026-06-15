package com.rmf.rdvp.api.operations;

import java.math.BigDecimal;

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
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.operations.FaultSeverity;
import com.rmf.rdvp.operations.FaultType;
import com.rmf.rdvp.operations.OperationsService;
import com.rmf.rdvp.operations.ReinspectionResult;
import com.rmf.rdvp.operations.RepairReportResult;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class OperationsController {

    private final OperationsService operationsService;

    public OperationsController(OperationsService operationsService) {
        this.operationsService = operationsService;
    }

    @PostMapping("/fault-reports")
    @PreAuthorize("hasAuthority('OPS_FAULT_REPORT_CREATE')")
    public ResponseEntity<ApiResponse<FaultReportResponse>> createFaultReport(
            @Valid @RequestBody CreateFaultReportRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.createFaultReport(
                requestBody.deviceCode(),
                parseEnum(FaultType.class, requestBody.faultType(), "faultType"),
                parseEnum(FaultSeverity.class, requestBody.severity(), "severity"),
                requestBody.occurredAt(),
                requestBody.description(),
                requestBody.sceneCondition(),
                requestBody.longitude(),
                requestBody.latitude(),
                user);
        return ResponseEntity.ok(ApiResponse.success(FaultReportResponse.from(result), RequestIds.resolve(request)));
    }

    @GetMapping("/repair-tasks/pool")
    @PreAuthorize("hasAuthority('OPS_REPAIR_TASK_ACCEPT')")
    public ResponseEntity<ApiResponse<RepairTaskPoolListResponse>> listRepairTaskPool(
            @RequestParam(defaultValue = "10") int radiusKm,
            @RequestParam(required = false) String severity,
            @RequestParam(required = false) BigDecimal longitude,
            @RequestParam(required = false) BigDecimal latitude,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.listRepairTaskPool(
                radiusKm,
                severity == null || severity.isBlank() ? null : parseEnum(FaultSeverity.class, severity, "severity"),
                longitude,
                latitude,
                user);
        return ResponseEntity.ok(ApiResponse.success(RepairTaskPoolListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/fault-reports/{faultReportId}/accept")
    @PreAuthorize("hasAuthority('OPS_REPAIR_TASK_ACCEPT')")
    public ResponseEntity<ApiResponse<RepairTaskAcceptResponse>> acceptFaultReport(
            @PathVariable String faultReportId,
            @RequestBody(required = false) RepairTaskAcceptRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.acceptFaultReport(
                faultReportId,
                requestBody == null ? null : requestBody.longitude(),
                requestBody == null ? null : requestBody.latitude(),
                user);
        return ResponseEntity.ok(ApiResponse.success(RepairTaskAcceptResponse.from(result), RequestIds.resolve(request)));
    }

    @GetMapping("/repair-tasks/accepted")
    @PreAuthorize("hasAuthority('OPS_REPAIR_REPORT_CREATE')")
    public ResponseEntity<ApiResponse<AcceptedRepairTaskListResponse>> listAcceptedRepairTasks(
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.listAcceptedRepairTasks(user);
        return ResponseEntity.ok(ApiResponse.success(AcceptedRepairTaskListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/repair-tasks/{repairTaskId}/repair-reports")
    @PreAuthorize("hasAuthority('OPS_REPAIR_REPORT_CREATE')")
    public ResponseEntity<ApiResponse<RepairReportResponse>> submitRepairReport(
            @PathVariable String repairTaskId,
            @Valid @RequestBody RepairReportRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.submitRepairReport(
                repairTaskId,
                parseEnum(RepairReportResult.class, requestBody.result(), "result"),
                requestBody.repairedAt(),
                requestBody.processDescription(),
                requestBody.partsUsed(),
                user);
        return ResponseEntity.ok(ApiResponse.success(RepairReportResponse.from(result), RequestIds.resolve(request)));
    }

    @GetMapping("/reinspections/pending")
    @PreAuthorize("hasAuthority('OPS_REINSPECTION_CREATE')")
    public ResponseEntity<ApiResponse<ReinspectionTaskListResponse>> listPendingReinspections(
            HttpServletRequest request) {
        var result = operationsService.listPendingReinspections();
        return ResponseEntity.ok(ApiResponse.success(ReinspectionTaskListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/reinspections/{faultReportId}/accept")
    @PreAuthorize("hasAuthority('OPS_REINSPECTION_CREATE')")
    public ResponseEntity<ApiResponse<RepairTaskAcceptResponse>> acceptReinspectionTask(
            @PathVariable String faultReportId,
            @RequestBody(required = false) RepairTaskAcceptRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.acceptReinspectionTask(
                faultReportId,
                requestBody == null ? null : requestBody.longitude(),
                requestBody == null ? null : requestBody.latitude(),
                user);
        return ResponseEntity.ok(ApiResponse.success(RepairTaskAcceptResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/fault-reports/{faultReportId}/reinspection-records")
    @PreAuthorize("hasAuthority('OPS_REINSPECTION_CREATE')")
    public ResponseEntity<ApiResponse<ReinspectionRecordResponse>> submitReinspectionRecord(
            @PathVariable String faultReportId,
            @Valid @RequestBody ReinspectionRecordRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.submitReinspectionRecord(
                faultReportId,
                parseEnum(ReinspectionResult.class, requestBody.result(), "result"),
                requestBody.reinspectedAt(),
                requestBody.description(),
                user);
        return ResponseEntity.ok(ApiResponse.success(ReinspectionRecordResponse.from(result), RequestIds.resolve(request)));
    }

    private <T extends Enum<T>> T parseEnum(Class<T> enumType, String value, String field) {
        try {
            return Enum.valueOf(enumType, value.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }
}
