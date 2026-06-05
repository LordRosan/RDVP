package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.rmf.rdvp.archive.DeviceArchive;
import com.rmf.rdvp.archive.DeviceArchiveRepository;
import com.rmf.rdvp.archive.DeviceVerificationRecord;
import com.rmf.rdvp.archive.DeviceVerificationRecordCreate;
import com.rmf.rdvp.archive.DeviceVerificationRepository;
import com.rmf.rdvp.archive.DeviceVerificationResult;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;

@Service
public class OperationsService {

    private static final int DEFAULT_RADIUS_KM = 10;
    private static final int MIN_RADIUS_KM = 1;
    private static final int IDLE_MAX_RADIUS_KM = 20;
    private static final int LOW_LOAD_MAX_RADIUS_KM = 10;
    private static final int MAX_ACTIVE_REPAIR_TASK_COUNT = 2;
    private static final int MAX_OPERATION_LIST_ITEMS = 100;
    private static final int MAX_AVAILABLE_REPAIR_TASK_CANDIDATES = 500;
    private static final int MAX_VERIFICATION_DESCRIPTION_LENGTH = 500;
    private static final int MAX_VERIFICATION_REMARK_LENGTH = 300;
    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Pattern BUSINESS_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final DateTimeFormatter LOCAL_DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final DateTimeFormatter BUSINESS_NO_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceVerificationRepository verificationRepository;
    private final OperationsRepository operationsRepository;
    private final AuditLogService auditLogService;

    public OperationsService(
            DeviceArchiveRepository archiveRepository,
            DeviceVerificationRepository verificationRepository,
            OperationsRepository operationsRepository,
            AuditLogService auditLogService) {
        this.archiveRepository = archiveRepository;
        this.verificationRepository = verificationRepository;
        this.operationsRepository = operationsRepository;
        this.auditLogService = auditLogService;
    }

    @Transactional
    public FaultReportRecord createFaultReport(
            String deviceCode,
            FaultType faultType,
            FaultSeverity severity,
            String occurredAt,
            String description,
            String sceneCondition,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser reporter) {
        DeviceArchive device = archiveRepository.findByCode(normalizeDeviceCode(deviceCode))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        if (operationsRepository.hasActiveFaultForDevice(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_ACTIVE_FAULT_EXISTS);
        }

        OffsetDateTime now = now();
        FaultReportCreate create = new FaultReportCreate(
                "fault-" + UUID.randomUUID(),
                newBusinessNo("RDF", now),
                device.id(),
                reporter.id(),
                requireEnum(faultType, "faultType"),
                requireEnum(severity, "severity"),
                normalizeRequiredText(description, "description", 1000, ErrorCode.FAULT_REPORT_INVALID),
                normalizeOptionalText(sceneCondition, 500, ErrorCode.FAULT_REPORT_INVALID),
                parseDateTime(occurredAt, "occurredAt"),
                longitude,
                latitude,
                now);

        try {
            operationsRepository.createFaultReport(create);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.DEVICE_ACTIVE_FAULT_EXISTS);
        }

        archiveRepository.updateStatus(device.id(), "FAULTED", reporter.id());
        FaultReportRecord record = operationsRepository.findFaultReportByIdOrNo(create.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR));
        auditLogService.recordSuccess(
                AuditAction.FAULT_REPORT,
                record.id(),
                record.faultReportNo(),
                reporter,
                "Submitted fault report.");
        return record;
    }

    @Transactional
    public DeviceVerificationFaultReportResult createVerificationWithFaultReport(
            String deviceId,
            DeviceVerificationResult result,
            String verificationDescription,
            String remark,
            String verifiedAt,
            FaultType faultType,
            FaultSeverity severity,
            String occurredAt,
            String faultDescription,
            String sceneCondition,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser operator) {
        DeviceVerificationResult normalizedResult = requireEnum(result, "result");
        if (normalizedResult == DeviceVerificationResult.NORMAL) {
            throw new BusinessException(
                    ErrorCode.DEVICE_VERIFICATION_INVALID,
                    "Normal verification does not require a fault report.");
        }

        DeviceArchive device = archiveRepository.findById(normalizeId(deviceId, "deviceId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        if (operationsRepository.hasActiveFaultForDevice(device.id())) {
            throw new BusinessException(ErrorCode.DEVICE_ACTIVE_FAULT_EXISTS);
        }

        OffsetDateTime normalizedVerifiedAt = parseDateTime(verifiedAt, "verifiedAt");
        OffsetDateTime now = now();
        DeviceVerificationRecordCreate verificationCreate = new DeviceVerificationRecordCreate(
                "verification-" + UUID.randomUUID(),
                device.id(),
                operator.id(),
                normalizedResult,
                normalizeRequiredText(
                        verificationDescription,
                        "description",
                        MAX_VERIFICATION_DESCRIPTION_LENGTH,
                        ErrorCode.DEVICE_VERIFICATION_INVALID),
                normalizeOptionalText(
                        remark,
                        MAX_VERIFICATION_REMARK_LENGTH,
                        ErrorCode.DEVICE_VERIFICATION_INVALID),
                normalizedVerifiedAt,
                now);
        verificationRepository.create(verificationCreate);
        archiveRepository.updateLastVerificationTime(device.id(), normalizedVerifiedAt, operator.id());

        FaultReportCreate faultCreate = new FaultReportCreate(
                "fault-" + UUID.randomUUID(),
                newBusinessNo("RDF", now),
                device.id(),
                operator.id(),
                requireEnum(faultType, "faultType"),
                requireEnum(severity, "severity"),
                normalizeRequiredText(faultDescription, "faultDescription", 1000, ErrorCode.FAULT_REPORT_INVALID),
                normalizeOptionalText(sceneCondition, 500, ErrorCode.FAULT_REPORT_INVALID),
                parseDateTime(occurredAt, "occurredAt"),
                longitude,
                latitude,
                now);

        try {
            operationsRepository.createFaultReport(faultCreate);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.DEVICE_ACTIVE_FAULT_EXISTS);
        }

        archiveRepository.updateStatus(device.id(), "FAULTED", operator.id());
        DeviceVerificationRecord verificationRecord = verificationRepository.findById(verificationCreate.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR));
        FaultReportRecord faultReport = operationsRepository.findFaultReportByIdOrNo(faultCreate.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR));
        auditLogService.recordSuccess(
                AuditAction.DEVICE_VERIFICATION,
                verificationRecord.id(),
                device.deviceCode(),
                operator,
                "Submitted abnormal device verification record.");
        auditLogService.recordSuccess(
                AuditAction.FAULT_REPORT,
                faultReport.id(),
                faultReport.faultReportNo(),
                operator,
                "Submitted fault report from device verification.");
        return new DeviceVerificationFaultReportResult(verificationRecord, faultReport);
    }

    public AvailableRepairTaskList listAvailableRepairTasks(
            int radiusKm,
            FaultSeverity severity,
            AuthenticatedUser maintainer) {
        int normalizedRadiusKm = normalizeRadiusKm(radiusKm);
        RepairerWorkloadSnapshot workload = currentWorkload(maintainer.id());
        validateWorkloadForRefresh(workload, normalizedRadiusKm);

        var items = operationsRepository.listAvailableRepairTasks(severity, MAX_AVAILABLE_REPAIR_TASK_CANDIDATES)
                .stream()
                .filter(item -> item.distanceKm() == null || item.distanceKm().compareTo(BigDecimal.valueOf(normalizedRadiusKm)) <= 0)
                .limit(MAX_OPERATION_LIST_ITEMS)
                .toList();
        return new AvailableRepairTaskList(normalizedRadiusKm, workload, items, items.size());
    }

    @Transactional
    public RepairTaskAcceptResult acceptFaultReport(String faultReportId, AuthenticatedUser maintainer) {
        RepairerWorkloadSnapshot workload = currentWorkload(maintainer.id());
        validateWorkloadForAccept(workload);

        String normalizedFaultReportId = normalizeId(faultReportId, "faultReportId");
        FaultReportRecord faultReport = operationsRepository.findFaultReportByIdOrNo(normalizedFaultReportId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FAULT_REPORT_NOT_FOUND));
        if (faultReport.status() != FaultStatus.PENDING_ACCEPTANCE
                || operationsRepository.hasActiveRepairTaskForFault(faultReport.id())) {
            throw new BusinessException(ErrorCode.FAULT_ALREADY_ACCEPTED);
        }

        OffsetDateTime now = now();
        RepairTaskCreate create = new RepairTaskCreate(
                "repair-task-" + UUID.randomUUID(),
                newBusinessNo("RDT", now),
                faultReport.id(),
                maintainer.id(),
                null,
                null,
                now);
        try {
            operationsRepository.createRepairTask(create);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.FAULT_ALREADY_ACCEPTED);
        }

        if (!operationsRepository.markFaultAccepted(faultReport.id(), create.id(), now)) {
            throw new BusinessException(ErrorCode.FAULT_ALREADY_ACCEPTED);
        }

        archiveRepository.updateStatus(faultReport.deviceId(), "UNDER_REPAIR", maintainer.id());
        auditLogService.recordSuccess(
                AuditAction.REPAIR_TASK_ACCEPT,
                create.id(),
                create.repairTaskNo(),
                maintainer,
                "Accepted repair task.");
        return new RepairTaskAcceptResult(create.id(), faultReport.id(), RepairTaskStatus.ACCEPTED, create.acceptedAt());
    }

    public MyRepairTaskList listMyRepairTasks(AuthenticatedUser maintainer) {
        var items = operationsRepository.listMyRepairTasks(maintainer.id(), MAX_OPERATION_LIST_ITEMS);
        return new MyRepairTaskList(items, items.size());
    }

    @Transactional
    public RepairReportRecord submitRepairReport(
            String repairTaskId,
            RepairReportResult result,
            String repairedAt,
            String processDescription,
            String partsUsed,
            AuthenticatedUser maintainer) {
        RepairTaskRecord task = operationsRepository.findRepairTaskByIdOrNo(normalizeId(repairTaskId, "repairTaskId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.REPAIR_TASK_NOT_FOUND));
        if (!task.maintainerId().equals(maintainer.id())) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_STATUS_INVALID, "Repair task does not belong to current user.");
        }

        if (task.status() != RepairTaskStatus.ACCEPTED && task.status() != RepairTaskStatus.PROCESSING) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_STATUS_INVALID);
        }

        RepairReportResult normalizedResult = requireEnum(result, "result");
        boolean requiresReinspection = requiresReinspection(task.severity(), normalizedResult);
        OffsetDateTime now = now();
        RepairReportCreate create = new RepairReportCreate(
                "repair-report-" + UUID.randomUUID(),
                newBusinessNo("RDR", now),
                task.id(),
                task.faultReportId(),
                maintainer.id(),
                normalizedResult,
                parseDateTime(repairedAt, "repairedAt"),
                normalizeRequiredText(processDescription, "processDescription", 1000, ErrorCode.REPAIR_REPORT_INVALID),
                normalizeOptionalText(partsUsed, 500, ErrorCode.REPAIR_REPORT_INVALID),
                requiresReinspection,
                now);

        try {
            operationsRepository.createRepairReport(create);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_STATUS_INVALID);
        }

        if (!operationsRepository.markRepairTaskReported(task.id(), now)) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_STATUS_INVALID);
        }

        FaultStatus nextFaultStatus = nextFaultStatus(task.severity(), normalizedResult);
        FaultStatus expectedFaultStatus = task.status() == RepairTaskStatus.PROCESSING
                ? FaultStatus.UNDER_REPAIR
                : FaultStatus.ACCEPTED;
        if (!operationsRepository.updateFaultStatusIfCurrent(task.faultReportId(), expectedFaultStatus, nextFaultStatus, now)) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_STATUS_INVALID);
        }

        archiveRepository.updateStatus(task.deviceId(), nextDeviceStatus(nextFaultStatus, normalizedResult), maintainer.id());
        RepairReportRecord record = toRecord(create);
        auditLogService.recordSuccess(
                AuditAction.REPAIR_REPORT,
                record.id(),
                record.repairReportNo(),
                maintainer,
                "Submitted repair report.");
        return record;
    }

    public ReinspectionTaskList listPendingReinspections() {
        var items = operationsRepository.listPendingReinspections(MAX_OPERATION_LIST_ITEMS);
        return new ReinspectionTaskList(items, items.size());
    }

    @Transactional
    public ReinspectionRecord submitReinspectionRecord(
            String faultReportId,
            ReinspectionResult result,
            String reinspectedAt,
            String description,
            AuthenticatedUser reinspector) {
        FaultReportRecord faultReport = operationsRepository.findFaultReportByIdOrNo(normalizeId(faultReportId, "faultReportId"))
                .orElseThrow(() -> new BusinessException(ErrorCode.FAULT_REPORT_NOT_FOUND));
        if (faultReport.status() != FaultStatus.PENDING_REINSPECTION) {
            throw new BusinessException(ErrorCode.REINSPECTION_REQUIRED);
        }

        RepairReportRecord repairReport = operationsRepository.findLatestRepairReportByFaultReportId(faultReport.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.REPAIR_REPORT_NOT_FOUND));
        ReinspectionResult normalizedResult = requireEnum(result, "result");
        OffsetDateTime now = now();
        ReinspectionRecordCreate create = new ReinspectionRecordCreate(
                "reinspection-" + UUID.randomUUID(),
                newBusinessNo("RDI", now),
                faultReport.id(),
                repairReport.id(),
                reinspector.id(),
                normalizedResult,
                parseDateTime(reinspectedAt, "reinspectedAt"),
                normalizeRequiredText(description, "description", 800, ErrorCode.REINSPECTION_RECORD_INVALID),
                now);
        FaultStatus nextFaultStatus = normalizedResult == ReinspectionResult.PASSED
                ? FaultStatus.CLOSED
                : FaultStatus.PENDING_ACCEPTANCE;
        String nextDeviceStatus = normalizedResult == ReinspectionResult.PASSED ? "NORMAL" : "FAULTED";

        try {
            operationsRepository.createReinspectionRecord(create);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.REINSPECTION_REQUIRED);
        }

        if (!operationsRepository.updateFaultStatusIfCurrent(
                faultReport.id(),
                FaultStatus.PENDING_REINSPECTION,
                nextFaultStatus,
                now)) {
            throw new BusinessException(ErrorCode.REINSPECTION_REQUIRED);
        }

        archiveRepository.updateStatus(faultReport.deviceId(), nextDeviceStatus, reinspector.id());
        ReinspectionRecord record = new ReinspectionRecord(
                create.id(),
                create.reinspectionRecordNo(),
                create.faultReportId(),
                create.repairReportId(),
                create.reinspectorId(),
                create.result(),
                create.reinspectedAt(),
                create.description(),
                nextFaultStatus,
                nextDeviceStatus,
                create.createdAt());
        auditLogService.recordSuccess(
                AuditAction.REINSPECTION_RECORD,
                record.id(),
                record.reinspectionRecordNo(),
                reinspector,
                "Submitted reinspection record.");
        return record;
    }

    private RepairReportRecord toRecord(RepairReportCreate create) {
        return new RepairReportRecord(
                create.id(),
                create.repairReportNo(),
                create.repairTaskId(),
                create.faultReportId(),
                create.maintainerId(),
                create.result(),
                create.repairedAt(),
                create.processDescription(),
                create.partsUsed(),
                create.requiresReinspection(),
                create.createdAt());
    }

    private RepairerWorkloadSnapshot currentWorkload(String maintainerId) {
        return createWorkloadSnapshot(operationsRepository.countActiveRepairTasksByMaintainer(maintainerId));
    }

    private RepairerWorkloadSnapshot createWorkloadSnapshot(int activeTaskCount) {
        int normalizedCount = Math.max(0, activeTaskCount);
        if (normalizedCount >= MAX_ACTIVE_REPAIR_TASK_COUNT) {
            return new RepairerWorkloadSnapshot(
                    RepairerWorkloadStatus.BUSY,
                    normalizedCount,
                    MAX_ACTIVE_REPAIR_TASK_COUNT,
                    0,
                    0,
                    "当前进行中的维修任务已达到上限，暂不可继续接取。请完成并提交维修报告后再刷新任务。",
                    false);
        }

        if (normalizedCount > 0) {
            return new RepairerWorkloadSnapshot(
                    RepairerWorkloadStatus.LOW_LOAD,
                    normalizedCount,
                    MAX_ACTIVE_REPAIR_TASK_COUNT,
                    LOW_LOAD_MAX_RADIUS_KM,
                    LOW_LOAD_MAX_RADIUS_KM,
                    "当前已有进行中的维修任务，系统已限制可接取范围。请优先处理已接取任务。",
                    true);
        }

        return new RepairerWorkloadSnapshot(
                RepairerWorkloadStatus.IDLE,
                normalizedCount,
                MAX_ACTIVE_REPAIR_TASK_COUNT,
                IDLE_MAX_RADIUS_KM,
                DEFAULT_RADIUS_KM,
                "当前无进行中的维修任务，可接取服务范围内的故障任务。",
                true);
    }

    private void validateWorkloadForRefresh(RepairerWorkloadSnapshot workload, int radiusKm) {
        validateWorkloadForAccept(workload);
        if (radiusKm > workload.maxRadiusKm()) {
            throw new BusinessException(
                    ErrorCode.REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD,
                    "当前处于%s状态，查询范围不能超过%d公里。".formatted(formatWorkloadStatus(workload.status()), workload.maxRadiusKm()));
        }
    }

    private void validateWorkloadForAccept(RepairerWorkloadSnapshot workload) {
        if (!workload.canAccept()) {
            throw new BusinessException(ErrorCode.REPAIRER_BUSY, workload.message());
        }
    }

    private int normalizeRadiusKm(int radiusKm) {
        if (radiusKm < MIN_RADIUS_KM || radiusKm > IDLE_MAX_RADIUS_KM) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_RADIUS_INVALID, "查询范围必须在1到20公里之间。");
        }

        return radiusKm;
    }

    private String normalizeDeviceCode(String deviceCode) {
        String normalized = deviceCode == null ? "" : deviceCode.trim().toUpperCase();
        if (!DEVICE_CODE_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_INVALID);
        }

        return normalized;
    }

    private String normalizeId(String id, String field) {
        String normalized = id == null ? "" : id.trim();
        if (!BUSINESS_ID_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }

        return normalized;
    }

    private OffsetDateTime parseDateTime(String value, String field) {
        String normalized = normalizeRequiredText(value, field, 64, ErrorCode.BAD_REQUEST);
        try {
            return OffsetDateTime.parse(normalized);
        } catch (DateTimeParseException ignored) {
        }

        try {
            return LocalDateTime.parse(normalized, LOCAL_DATE_TIME_FORMATTER).atOffset(ZoneOffset.UTC);
        } catch (DateTimeParseException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }

    private String normalizeRequiredText(String value, String field, int maxLength, ErrorCode errorCode) {
        String normalized = normalizeOptionalText(value, maxLength, errorCode);
        if (normalized.isBlank()) {
            throw new BusinessException(errorCode, field + " is required.");
        }

        return normalized;
    }

    private String normalizeOptionalText(String value, int maxLength, ErrorCode errorCode) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.length() > maxLength) {
            throw new BusinessException(errorCode, "Text field must not exceed " + maxLength + " characters.");
        }

        return normalized;
    }

    private <T> T requireEnum(T value, String field) {
        if (value == null) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }

        return value;
    }

    private boolean requiresReinspection(FaultSeverity severity, RepairReportResult result) {
        return result != RepairReportResult.UNRESOLVED && (severity == FaultSeverity.EMERGENCY || severity == FaultSeverity.SEVERE);
    }

    private FaultStatus nextFaultStatus(FaultSeverity severity, RepairReportResult result) {
        if (result == RepairReportResult.UNRESOLVED) {
            return FaultStatus.UNDER_REPAIR;
        }

        return requiresReinspection(severity, result) ? FaultStatus.PENDING_REINSPECTION : FaultStatus.CLOSED;
    }

    private String nextDeviceStatus(FaultStatus nextFaultStatus, RepairReportResult result) {
        if (result == RepairReportResult.UNRESOLVED) {
            return "UNDER_REPAIR";
        }

        return nextFaultStatus == FaultStatus.PENDING_REINSPECTION ? "PENDING_REINSPECTION" : "NORMAL";
    }

    private String formatWorkloadStatus(RepairerWorkloadStatus status) {
        return switch (status) {
            case IDLE -> "空闲";
            case LOW_LOAD -> "低负载";
            case BUSY -> "忙碌";
        };
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }

    private String newBusinessNo(String prefix, OffsetDateTime now) {
        return "%s-%s-%s".formatted(
                prefix,
                now.format(BUSINESS_NO_TIME_FORMATTER),
                UUID.randomUUID().toString().substring(0, 6).toUpperCase());
    }
}
