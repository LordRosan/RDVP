package com.rmf.rdvp.operations.api;

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

import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticatedUser;
import com.rmf.rdvp.user.AuthenticationService;
import com.rmf.rdvp.operations.FaultSeverity;
import com.rmf.rdvp.operations.FaultType;
import com.rmf.rdvp.operations.OperationsReviewDecision;
import com.rmf.rdvp.operations.OperationsService;
import com.rmf.rdvp.operations.ReinspectionResult;
import com.rmf.rdvp.operations.RepairReportResult;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class OperationsController {

    private final OperationsService operationsService;
    private final AuthenticationService authenticationService;

    public OperationsController(
            OperationsService operationsService,
            AuthenticationService authenticationService) {
        this.operationsService = operationsService;
        this.authenticationService = authenticationService;
    }

    @PostMapping("/fault-reports")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT')")
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

    @GetMapping("/operation-tasks/available")
    @PreAuthorize("hasAnyAuthority('OPERATIONS_CENTER_REPAIR_TASK_ACCEPT','OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT')")
    public ResponseEntity<ApiResponse<TaskAcceptanceListResponse>> listTaskAcceptance(
            @RequestParam(defaultValue = "10") int radiusKm,
            @RequestParam(required = false) String severity,
            @RequestParam(required = false) BigDecimal longitude,
            @RequestParam(required = false) BigDecimal latitude,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.listTaskAcceptance(
                radiusKm,
                severity == null || severity.isBlank() ? null : parseEnum(FaultSeverity.class, severity, "severity"),
                longitude,
                latitude,
                user);
        return ResponseEntity.ok(ApiResponse.success(TaskAcceptanceListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/fault-reports/{faultReportId}/accept")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_REPAIR_TASK_ACCEPT')")
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
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT')")
    public ResponseEntity<ApiResponse<RepairTaskListResponse>> listRepairTasks(
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var result = operationsService.listRepairTasks(user);
        return ResponseEntity.ok(ApiResponse.success(RepairTaskListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/repair-tasks/{repairTaskId}/repair-reports")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT')")
    public ResponseEntity<ApiResponse<RepairReportResponse>> submitRepairReport(
            @PathVariable String repairTaskId,
            @Valid @RequestBody RepairReportRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        authenticationService.consumeRecentPasswordVerification(user);
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
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT')")
    public ResponseEntity<ApiResponse<ReinspectionTaskListResponse>> listPendingReinspections(
            HttpServletRequest request) {
        var result = operationsService.listPendingReinspections();
        return ResponseEntity.ok(ApiResponse.success(ReinspectionTaskListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/reinspections/{faultReportId}/accept")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT')")
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

    @PostMapping("/fault-reports/{faultReportId}/reinspection-reports")
    @PreAuthorize("hasAuthority('OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT')")
    public ResponseEntity<ApiResponse<ReinspectionReportResponse>> submitReinspectionReport(
            @PathVariable String faultReportId,
            @Valid @RequestBody ReinspectionReportRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        authenticationService.consumeRecentPasswordVerification(user);
        var result = operationsService.submitReinspectionReport(
                faultReportId,
                parseEnum(ReinspectionResult.class, requestBody.result(), "result"),
                requestBody.reinspectedAt(),
                requestBody.description(),
                user);
        return ResponseEntity.ok(ApiResponse.success(ReinspectionReportResponse.from(result), RequestIds.resolve(request)));
    }

    @GetMapping("/operations-review-requests")
    @PreAuthorize("hasAuthority('REVIEW_CENTER_OPERATIONS_REVIEW')")
    public ResponseEntity<ApiResponse<OperationsReviewRequestListResponse>> listOperationsReviewRequests(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            HttpServletRequest request) {
        var result = operationsService.listOperationsReviewRequests(status, type, keyword, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(OperationsReviewRequestListResponse.from(result), RequestIds.resolve(request)));
    }

    @PostMapping("/operations-review-requests/{requestId}/review")
    @PreAuthorize("hasAuthority('REVIEW_CENTER_OPERATIONS_REVIEW')")
    public ResponseEntity<ApiResponse<OperationsReviewResultResponse>> reviewOperationsRequest(
            @PathVariable String requestId,
            @Valid @RequestBody ReviewOperationsRequest requestBody,
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        OperationsReviewDecision decision = parseEnum(OperationsReviewDecision.class, requestBody.decision(), "decision");
        authenticationService.consumeRecentPasswordVerification(user);
        var result = operationsService.reviewOperationsRequest(
                requestId,
                decision,
                requestBody.reviewedAt(),
                requestBody.reviewComment(),
                user);
        return ResponseEntity.ok(ApiResponse.success(OperationsReviewResultResponse.from(result), RequestIds.resolve(request)));
    }

    private <T extends Enum<T>> T parseEnum(Class<T> enumType, String value, String field) {
        try {
            return Enum.valueOf(enumType, value.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }
}
