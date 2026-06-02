package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.rmf.rdvp.archive.DeviceArchive;
import com.rmf.rdvp.archive.DeviceArchiveRepository;
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
    private static final Pattern DEVICE_CODE_PATTERN = Pattern.compile("^RDVP-DEVICE-\\d{4}$");
    private static final Pattern BUSINESS_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final DateTimeFormatter LOCAL_DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final DateTimeFormatter BUSINESS_NO_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final DeviceArchiveRepository archiveRepository;
    private final OperationsRepository operationsRepository;

    public OperationsService(DeviceArchiveRepository archiveRepository, OperationsRepository operationsRepository) {
        this.archiveRepository = archiveRepository;
        this.operationsRepository = operationsRepository;
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

        operationsRepository.createFaultReport(create);
        archiveRepository.updateStatus(device.id(), "FAULTED", reporter.id());
        return operationsRepository.findFaultReportByIdOrNo(create.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR));
    }

    public AvailableRepairTaskList listAvailableRepairTasks(
            int radiusKm,
            FaultSeverity severity,
            AuthenticatedUser maintainer) {
        int normalizedRadiusKm = normalizeRadiusKm(radiusKm);
        RepairerWorkloadSnapshot workload = currentWorkload(maintainer.id());
        validateWorkloadForRefresh(workload, normalizedRadiusKm);

        var items = operationsRepository.listAvailableRepairTasks(severity)
                .stream()
                .filter(item -> item.distanceKm() == null || item.distanceKm().compareTo(BigDecimal.valueOf(normalizedRadiusKm)) <= 0)
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
        operationsRepository.createRepairTask(create);
        operationsRepository.markFaultAccepted(faultReport.id(), create.id(), now);
        archiveRepository.updateStatus(faultReport.deviceId(), "UNDER_REPAIR", maintainer.id());
        return new RepairTaskAcceptResult(create.id(), faultReport.id(), RepairTaskStatus.ACCEPTED, create.acceptedAt());
    }

    public MyRepairTaskList listMyRepairTasks(AuthenticatedUser maintainer) {
        var items = operationsRepository.listMyRepairTasks(maintainer.id());
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

        operationsRepository.createRepairReport(create);
        operationsRepository.markRepairTaskReported(task.id(), now);
        FaultStatus nextFaultStatus = nextFaultStatus(task.severity(), normalizedResult);
        operationsRepository.updateFaultStatus(task.faultReportId(), nextFaultStatus, now);
        archiveRepository.updateStatus(task.deviceId(), nextDeviceStatus(nextFaultStatus, normalizedResult), maintainer.id());
        return toRecord(create);
    }

    public ReinspectionTaskList listPendingReinspections() {
        var items = operationsRepository.listPendingReinspections();
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

        operationsRepository.createReinspectionRecord(create);
        operationsRepository.updateFaultStatus(faultReport.id(), nextFaultStatus, now);
        archiveRepository.updateStatus(faultReport.deviceId(), nextDeviceStatus, reinspector.id());
        return new ReinspectionRecord(
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
