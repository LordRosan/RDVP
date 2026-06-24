package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;
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
import com.rmf.rdvp.identity.PermissionCode;

@Service
public class OperationsService {

    private static final int DEFAULT_RADIUS_KM = 10;
    private static final int MIN_RADIUS_KM = 1;
    private static final int IDLE_MAX_RADIUS_KM = 30;
    private static final int LOW_LOAD_MAX_RADIUS_KM = 20;
    private static final int MEDIUM_LOAD_MAX_RADIUS_KM = 10;
    private static final int MAX_ACTIVE_REPAIR_TASK_COUNT = 3;
    private static final int MAX_OPERATION_LIST_ITEMS = 100;
    private static final int MAX_TASK_ACCEPTANCE_CANDIDATES = 500;
    private static final int MAX_VERIFICATION_DESCRIPTION_LENGTH = 500;
    private static final int MAX_VERIFICATION_REMARK_LENGTH = 300;
    private static final int MAX_REVIEW_COMMENT_LENGTH = 500;
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
        try {
            return createFaultReportChecked(
                    deviceCode,
                    faultType,
                    severity,
                    occurredAt,
                    description,
                    sceneCondition,
                    longitude,
                    latitude,
                    reporter);
        } catch (BusinessException exception) {
            recordFaultReportFailure(deviceCode, reporter, exception);
            throw exception;
        }
    }

    private FaultReportRecord createFaultReportChecked(
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
        BigDecimal normalizedLongitude = normalizeCoordinate(
                longitude,
                "longitude",
                BigDecimal.valueOf(-180),
                BigDecimal.valueOf(180),
                ErrorCode.FAULT_REPORT_INVALID);
        BigDecimal normalizedLatitude = normalizeCoordinate(
                latitude,
                "latitude",
                BigDecimal.valueOf(-90),
                BigDecimal.valueOf(90),
                ErrorCode.FAULT_REPORT_INVALID);
        if ((normalizedLongitude == null) != (normalizedLatitude == null)) {
            throw new BusinessException(
                    ErrorCode.FAULT_REPORT_INVALID,
                    "longitude and latitude must be provided together.");
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
                normalizedLongitude,
                normalizedLatitude,
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
        createOperationsReviewRequest(
                OperationsReviewRequestType.FAULT_REPORT,
                record.id(),
                record.faultReportNo(),
                record.id(),
                record.deviceId(),
                reporter.id(),
                "报修类型：%s；故障等级：%s；报修说明：%s".formatted(
                        record.faultType().name(),
                        record.severity().name(),
                        record.description()),
                record.createdAt());
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
        DeviceArchive device = null;
        try {
            DeviceVerificationResult normalizedResult = requireEnum(result, "result");
            if (normalizedResult == DeviceVerificationResult.NORMAL) {
                throw new BusinessException(
                        ErrorCode.DEVICE_VERIFICATION_INVALID,
                        "Normal verification does not require a fault report.");
            }

            device = archiveRepository.findById(normalizeId(deviceId, "deviceId"))
                    .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
            if (operationsRepository.hasActiveFaultForDevice(device.id())) {
                throw new BusinessException(ErrorCode.DEVICE_ACTIVE_FAULT_EXISTS);
            }
            BigDecimal normalizedLongitude = normalizeCoordinate(
                    longitude,
                    "longitude",
                    BigDecimal.valueOf(-180),
                    BigDecimal.valueOf(180),
                    ErrorCode.FAULT_REPORT_INVALID);
            BigDecimal normalizedLatitude = normalizeCoordinate(
                    latitude,
                    "latitude",
                    BigDecimal.valueOf(-90),
                    BigDecimal.valueOf(90),
                    ErrorCode.FAULT_REPORT_INVALID);
            if ((normalizedLongitude == null) != (normalizedLatitude == null)) {
                throw new BusinessException(
                        ErrorCode.FAULT_REPORT_INVALID,
                        "longitude and latitude must be provided together.");
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
                    normalizedLongitude,
                    normalizedLatitude,
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
            createOperationsReviewRequest(
                    OperationsReviewRequestType.DEVICE_VERIFICATION_REPORT,
                    verificationRecord.id(),
                    verificationRecord.id(),
                    faultReport.id(),
                    device.id(),
                    operator.id(),
                    "核验结果：%s；核验说明：%s".formatted(
                            verificationRecord.result().name(),
                            verificationRecord.description()),
                    verificationRecord.createdAt());
            createOperationsReviewRequest(
                    OperationsReviewRequestType.FAULT_REPORT,
                    faultReport.id(),
                    faultReport.faultReportNo(),
                    faultReport.id(),
                    device.id(),
                    operator.id(),
                    "报修类型：%s；故障等级：%s；报修说明：%s".formatted(
                            faultReport.faultType().name(),
                            faultReport.severity().name(),
                            faultReport.description()),
                    faultReport.createdAt());
            return new DeviceVerificationFaultReportResult(verificationRecord, faultReport);
        } catch (BusinessException exception) {
            recordDeviceVerificationFailure(deviceId, device, operator, exception);
            throw exception;
        }
    }

    public TaskAcceptanceList listTaskAcceptance(
            int radiusKm,
            FaultSeverity severity,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser maintainer) {
        int normalizedRadiusKm = normalizeRadiusKm(radiusKm);
        BigDecimal normalizedLongitude = normalizeCoordinate(longitude, "longitude", BigDecimal.valueOf(-180), BigDecimal.valueOf(180));
        BigDecimal normalizedLatitude = normalizeCoordinate(latitude, "latitude", BigDecimal.valueOf(-90), BigDecimal.valueOf(90));
        if ((normalizedLongitude == null) != (normalizedLatitude == null)) {
            throw new BusinessException(
                    ErrorCode.REPAIR_TASK_RADIUS_INVALID,
                    "longitude and latitude must be provided together.");
        }

        RepairerWorkloadSnapshot workload = currentWorkload(maintainer.id());
        validateWorkloadForRefresh(workload, normalizedRadiusKm);
        boolean canAcceptRepairTasks = hasPermission(maintainer, PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT);
        boolean canAcceptReinspectionTasks = hasPermission(maintainer, PermissionCode.OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT);
        if (!canAcceptRepairTasks && !canAcceptReinspectionTasks) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        var items = operationsRepository.listTaskAcceptance(
                        severity,
                        normalizedRadiusKm,
                        normalizedLongitude,
                        normalizedLatitude,
                        canAcceptRepairTasks,
                        canAcceptReinspectionTasks,
                        MAX_TASK_ACCEPTANCE_CANDIDATES)
                .stream()
                .limit(MAX_OPERATION_LIST_ITEMS)
                .toList();
        return new TaskAcceptanceList(normalizedRadiusKm, workload, items, items.size());
    }

    @Transactional
    public RepairTaskAcceptResult acceptFaultReport(
            String faultReportId,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser maintainer) {
        try {
            return acceptFaultReportChecked(faultReportId, longitude, latitude, maintainer);
        } catch (BusinessException exception) {
            recordRepairTaskAcceptFailure(faultReportId, maintainer, exception);
            throw exception;
        }
    }

    private RepairTaskAcceptResult acceptFaultReportChecked(
            String faultReportId,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser maintainer) {
        RepairerWorkloadSnapshot workload = currentWorkload(maintainer.id());
        validateWorkloadForAccept(workload);
        BigDecimal normalizedLongitude = normalizeRequiredCoordinate(
                longitude,
                "longitude",
                BigDecimal.valueOf(-180),
                BigDecimal.valueOf(180));
        BigDecimal normalizedLatitude = normalizeRequiredCoordinate(
                latitude,
                "latitude",
                BigDecimal.valueOf(-90),
                BigDecimal.valueOf(90));

        String normalizedFaultReportId = normalizeId(faultReportId, "faultReportId");
        FaultReportRecord faultReport = operationsRepository.findFaultReportByIdOrNo(normalizedFaultReportId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FAULT_REPORT_NOT_FOUND));
        if (faultReport.status() != FaultStatus.PENDING_ACCEPTANCE
                || operationsRepository.hasActiveRepairTaskForFault(faultReport.id())) {
            throw new BusinessException(ErrorCode.FAULT_ALREADY_ACCEPTED);
        }
        DeviceArchive device = archiveRepository.findById(faultReport.deviceId())
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        validateRepairTaskDistance(workload, device, normalizedLongitude, normalizedLatitude);

        OffsetDateTime now = now();
        RepairTaskCreate create = new RepairTaskCreate(
                "repair-task-" + UUID.randomUUID(),
                newBusinessNo("RDT", now),
                faultReport.id(),
                maintainer.id(),
                normalizedLongitude,
                normalizedLatitude,
                now,
                "REPAIR");
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

    public RepairTaskList listRepairTasks(AuthenticatedUser maintainer) {
        var items = operationsRepository.listRepairTasks(maintainer.id(), MAX_OPERATION_LIST_ITEMS);
        return new RepairTaskList(items, items.size());
    }

    @Transactional
    public RepairReportRecord submitRepairReport(
            String repairTaskId,
            RepairReportResult result,
            String repairedAt,
            String processDescription,
            String partsUsed,
            AuthenticatedUser maintainer) {
        try {
            return submitRepairReportChecked(repairTaskId, result, repairedAt, processDescription, partsUsed, maintainer);
        } catch (BusinessException exception) {
            recordRepairReportFailure(repairTaskId, maintainer, exception);
            throw exception;
        }
    }

    private RepairReportRecord submitRepairReportChecked(
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

        archiveRepository.updateStatus(task.deviceId(), nextDeviceStatus(nextFaultStatus), maintainer.id());
        RepairReportRecord record = toRecord(create);
        createOperationsReviewRequest(
                OperationsReviewRequestType.REPAIR_REPORT,
                record.id(),
                record.repairReportNo(),
                record.faultReportId(),
                task.deviceId(),
                maintainer.id(),
                "维修结果：%s；维修说明：%s".formatted(
                        record.result().name(),
                        record.processDescription()),
                record.createdAt());
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
    public RepairTaskAcceptResult acceptReinspectionTask(
            String faultReportId,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser reinspector) {
        try {
            return acceptReinspectionTaskChecked(faultReportId, longitude, latitude, reinspector);
        } catch (BusinessException exception) {
            recordReinspectionAcceptFailure(faultReportId, reinspector, exception);
            throw exception;
        }
    }

    private RepairTaskAcceptResult acceptReinspectionTaskChecked(
            String faultReportId,
            BigDecimal longitude,
            BigDecimal latitude,
            AuthenticatedUser reinspector) {
        RepairerWorkloadSnapshot workload = currentWorkload(reinspector.id());
        validateWorkloadForAccept(workload);
        BigDecimal normalizedLongitude = normalizeRequiredCoordinate(
                longitude,
                "longitude",
                BigDecimal.valueOf(-180),
                BigDecimal.valueOf(180));
        BigDecimal normalizedLatitude = normalizeRequiredCoordinate(
                latitude,
                "latitude",
                BigDecimal.valueOf(-90),
                BigDecimal.valueOf(90));

        String normalizedFaultReportId = normalizeId(faultReportId, "faultReportId");
        FaultReportRecord faultReport = operationsRepository.findFaultReportByIdOrNo(normalizedFaultReportId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FAULT_REPORT_NOT_FOUND));
        if (faultReport.status() != FaultStatus.PENDING_REINSPECTION) {
            throw new BusinessException(ErrorCode.REINSPECTION_REQUIRED, "Fault is not pending reinspection.");
        }
        if (operationsRepository.hasActiveReinspectionTaskForFault(faultReport.id())) {
            throw new BusinessException(ErrorCode.REINSPECTION_REQUIRED, "An active reinspection task already exists for this fault.");
        }
        DeviceArchive device = archiveRepository.findById(faultReport.deviceId())
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
        validateRepairTaskDistance(workload, device, normalizedLongitude, normalizedLatitude);

        OffsetDateTime now = now();
        RepairTaskCreate create = new RepairTaskCreate(
                "reinspection-task-" + UUID.randomUUID(),
                newBusinessNo("RDT", now),
                faultReport.id(),
                reinspector.id(),
                normalizedLongitude,
                normalizedLatitude,
                now,
                "REINSPECTION");
        try {
            operationsRepository.createRepairTask(create);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.REINSPECTION_REQUIRED, "Failed to create reinspection task.");
        }

        auditLogService.recordSuccess(
                AuditAction.REPAIR_TASK_ACCEPT,
                create.id(),
                create.repairTaskNo(),
                reinspector,
                "Accepted reinspection task.");
        return new RepairTaskAcceptResult(create.id(), faultReport.id(), RepairTaskStatus.ACCEPTED, create.acceptedAt());
    }

    @Transactional
    public ReinspectionRecord submitReinspectionRecord(
            String faultReportId,
            ReinspectionResult result,
            String reinspectedAt,
            String description,
            AuthenticatedUser reinspector) {
        try {
            return submitReinspectionRecordChecked(faultReportId, result, reinspectedAt, description, reinspector);
        } catch (BusinessException exception) {
            recordReinspectionRecordFailure(faultReportId, reinspector, exception);
            throw exception;
        }
    }

    private ReinspectionRecord submitReinspectionRecordChecked(
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
        createOperationsReviewRequest(
                OperationsReviewRequestType.REINSPECTION_REPORT,
                record.id(),
                record.reinspectionRecordNo(),
                record.faultReportId(),
                faultReport.deviceId(),
                reinspector.id(),
                "复检结果：%s；复检说明：%s".formatted(
                        record.result().name(),
                        record.description()),
                record.createdAt());
        auditLogService.recordSuccess(
                AuditAction.REINSPECTION_RECORD,
                record.id(),
                record.reinspectionRecordNo(),
                reinspector,
                "Submitted reinspection record.");
        return record;
    }

    public OperationsReviewRequestPage listOperationsReviewRequests(
            String status,
            String type,
            String keyword,
            int page,
            int pageSize) {
        int normalizedPage = Math.max(1, page);
        int normalizedPageSize = Math.max(1, Math.min(pageSize, MAX_OPERATION_LIST_ITEMS));
        OperationsReviewRequestStatus normalizedStatus = parseOptionalOperationsReviewStatus(status);
        OperationsReviewRequestType normalizedType = parseOptionalOperationsReviewType(type);
        return operationsRepository.listOperationsReviewRequests(
                normalizedStatus,
                normalizedType,
                keyword,
                normalizedPageSize,
                (normalizedPage - 1) * normalizedPageSize);
    }

    @Transactional
    public OperationsReviewRequest reviewOperationsRequest(
            String requestId,
            OperationsReviewDecision decision,
            String reviewedAtText,
            String reviewComment,
            AuthenticatedUser reviewOperator) {
        String normalizedRequestId = normalizeId(requestId, "requestId");
        OperationsReviewRequest request = operationsRepository.findOperationsReviewRequestById(normalizedRequestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.OPERATIONS_REVIEW_REQUEST_NOT_FOUND));
        if (request.status() != OperationsReviewRequestStatus.PENDING_REVIEW) {
            throw new BusinessException(ErrorCode.OPERATIONS_REVIEW_REQUEST_ALREADY_REVIEWED);
        }

        OperationsReviewDecision normalizedDecision = requireEnum(decision, "decision");
        String normalizedComment = normalizeOptionalText(reviewComment, MAX_REVIEW_COMMENT_LENGTH,
                ErrorCode.OPERATIONS_REVIEW_REQUEST_INVALID);
        if (normalizedDecision == OperationsReviewDecision.REJECTED && normalizedComment.isBlank()) {
            throw new BusinessException(
                    ErrorCode.OPERATIONS_REVIEW_REQUEST_INVALID,
                    "reviewComment is required when rejecting an operations review request.");
        }

        OffsetDateTime reviewedAt = parseDateTime(reviewedAtText, "reviewedAt");
        OperationsReviewRequestStatus nextStatus = normalizedDecision == OperationsReviewDecision.APPROVED
                ? OperationsReviewRequestStatus.APPROVED
                : OperationsReviewRequestStatus.REJECTED;
        boolean reviewed = operationsRepository.markOperationsReviewRequestReviewed(
                request.id(),
                nextStatus,
                reviewOperator.id(),
                normalizedComment,
                reviewedAt);
        if (!reviewed) {
            throw new BusinessException(ErrorCode.OPERATIONS_REVIEW_REQUEST_ALREADY_REVIEWED);
        }

        OperationsReviewRequest updated = operationsRepository.findOperationsReviewRequestById(request.id())
                .orElseThrow(() -> new BusinessException(ErrorCode.OPERATIONS_REVIEW_REQUEST_NOT_FOUND));
        auditLogService.recordSuccess(
                AuditAction.OPERATIONS_REVIEW,
                updated.id(),
                updated.targetNo(),
                reviewOperator,
                normalizedDecision == OperationsReviewDecision.APPROVED
                        ? "Approved operations review request."
                        : "Rejected operations review request.");
        return updated;
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

    private void createOperationsReviewRequest(
            OperationsReviewRequestType type,
            String targetId,
            String targetNo,
            String faultReportId,
            String deviceId,
            String operatorId,
            String summary,
            OffsetDateTime submittedAt) {
        operationsRepository.createOperationsReviewRequest(new OperationsReviewRequestCreate(
                "operations-review-" + UUID.randomUUID(),
                type,
                targetId,
                targetNo,
                faultReportId,
                deviceId,
                operatorId,
                normalizeOptionalText(summary, 500, ErrorCode.OPERATIONS_REVIEW_REQUEST_INVALID),
                submittedAt,
                now()));
    }

    private void recordRepairTaskAcceptFailure(
            String faultReportId,
            AuthenticatedUser maintainer,
            BusinessException exception) {
        String normalizedFaultReportId = normalizeAuditTarget(faultReportId);
        auditLogService.recordFailure(
                AuditAction.REPAIR_TASK_ACCEPT,
                normalizedFaultReportId,
                resolveFaultReportTargetNo(normalizedFaultReportId),
                maintainer,
                "维修任务接取失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private void recordFaultReportFailure(
            String deviceCode,
            AuthenticatedUser reporter,
            BusinessException exception) {
        String normalizedDeviceCode = normalizeAuditDeviceCode(deviceCode);
        auditLogService.recordFailure(
                AuditAction.FAULT_REPORT,
                resolveDeviceIdByCode(normalizedDeviceCode),
                normalizedDeviceCode,
                reporter,
                "设备报修提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private void recordDeviceVerificationFailure(
            String deviceId,
            DeviceArchive device,
            AuthenticatedUser operator,
            BusinessException exception) {
        String normalizedDeviceId = normalizeAuditTarget(deviceId);
        auditLogService.recordFailure(
                AuditAction.DEVICE_VERIFICATION,
                device == null ? normalizedDeviceId : device.id(),
                device == null ? resolveDeviceCodeById(normalizedDeviceId) : device.deviceCode(),
                operator,
                "设备核验联动报修失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private void recordRepairReportFailure(
            String repairTaskId,
            AuthenticatedUser maintainer,
            BusinessException exception) {
        String normalizedRepairTaskId = normalizeAuditTarget(repairTaskId);
        auditLogService.recordFailure(
                AuditAction.REPAIR_REPORT,
                normalizedRepairTaskId,
                resolveRepairTaskTargetNo(normalizedRepairTaskId),
                maintainer,
                "维修报告提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private void recordReinspectionRecordFailure(
            String faultReportId,
            AuthenticatedUser reinspector,
            BusinessException exception) {
        String normalizedFaultReportId = normalizeAuditTarget(faultReportId);
        auditLogService.recordFailure(
                AuditAction.REINSPECTION_RECORD,
                normalizedFaultReportId,
                resolveFaultReportTargetNo(normalizedFaultReportId),
                reinspector,
                "复检报告提交失败：%s。".formatted(exception.getErrorCode().code()));
    }

    private void recordReinspectionAcceptFailure(
            String faultReportId,
            AuthenticatedUser reinspector,
            BusinessException exception) {
        String normalizedFaultReportId = normalizeAuditTarget(faultReportId);
        auditLogService.recordFailure(
                AuditAction.REPAIR_TASK_ACCEPT,
                normalizedFaultReportId,
                resolveFaultReportTargetNo(normalizedFaultReportId),
                reinspector,
                "复检任务接取失败：%s。".formatted(exception.getErrorCode().code()));
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

        if (normalizedCount == 2) {
            return new RepairerWorkloadSnapshot(
                    RepairerWorkloadStatus.MEDIUM_LOAD,
                    normalizedCount,
                    MAX_ACTIVE_REPAIR_TASK_COUNT,
                    MEDIUM_LOAD_MAX_RADIUS_KM,
                    MEDIUM_LOAD_MAX_RADIUS_KM,
                    "当前已有2个进行中的维修任务，系统已限制可接取范围。请优先处理已接取任务。",
                    true);
        }

        if (normalizedCount == 1) {
            return new RepairerWorkloadSnapshot(
                    RepairerWorkloadStatus.LOW_LOAD,
                    normalizedCount,
                    MAX_ACTIVE_REPAIR_TASK_COUNT,
                    LOW_LOAD_MAX_RADIUS_KM,
                    LOW_LOAD_MAX_RADIUS_KM,
                    "当前已有1个进行中的维修任务，系统已限制可接取范围。请优先处理已接取任务。",
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

    private void validateRepairTaskDistance(
            RepairerWorkloadSnapshot workload,
            DeviceArchive device,
            BigDecimal longitude,
            BigDecimal latitude) {
        if (device.longitude() == null || device.latitude() == null) {
            throw new BusinessException(
                    ErrorCode.REPAIR_TASK_RADIUS_INVALID,
                    "Device location is unavailable.");
        }

        BigDecimal distanceKm = calculateDistanceKm(longitude, latitude, device.longitude(), device.latitude());
        if (distanceKm.compareTo(BigDecimal.valueOf(workload.maxRadiusKm())) > 0) {
            throw new BusinessException(
                    ErrorCode.REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD,
                    "当前处于%s状态，仅可接取%d公里内的维修任务。"
                            .formatted(formatWorkloadStatus(workload.status()), workload.maxRadiusKm()));
        }
    }

    private int normalizeRadiusKm(int radiusKm) {
        if (radiusKm < MIN_RADIUS_KM || radiusKm > IDLE_MAX_RADIUS_KM) {
            throw new BusinessException(ErrorCode.REPAIR_TASK_RADIUS_INVALID, "查询范围必须在1到30公里之间。");
        }

        return radiusKm;
    }

    private BigDecimal normalizeCoordinate(BigDecimal value, String field, BigDecimal min, BigDecimal max) {
        return normalizeCoordinate(value, field, min, max, ErrorCode.REPAIR_TASK_RADIUS_INVALID);
    }

    private BigDecimal normalizeCoordinate(
            BigDecimal value,
            String field,
            BigDecimal min,
            BigDecimal max,
            ErrorCode errorCode) {
        if (value == null) {
            return null;
        }

        if (value.compareTo(min) < 0 || value.compareTo(max) > 0) {
            throw new BusinessException(errorCode, field + " is out of range.");
        }

        return value;
    }

    private BigDecimal normalizeRequiredCoordinate(BigDecimal value, String field, BigDecimal min, BigDecimal max) {
        if (value == null) {
            throw new BusinessException(
                    ErrorCode.REPAIR_TASK_RADIUS_INVALID,
                    field + " is required when accepting a repair task.");
        }

        return normalizeCoordinate(value, field, min, max);
    }

    private BigDecimal calculateDistanceKm(
            BigDecimal sourceLongitude,
            BigDecimal sourceLatitude,
            BigDecimal targetLongitude,
            BigDecimal targetLatitude) {
        double earthRadiusKm = 6371.0088;
        double sourceLat = Math.toRadians(sourceLatitude.doubleValue());
        double targetLat = Math.toRadians(targetLatitude.doubleValue());
        double deltaLat = Math.toRadians(targetLatitude.subtract(sourceLatitude).doubleValue());
        double deltaLon = Math.toRadians(targetLongitude.subtract(sourceLongitude).doubleValue());
        double a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)
                + Math.cos(sourceLat) * Math.cos(targetLat)
                * Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return BigDecimal.valueOf(earthRadiusKm * c).setScale(2, RoundingMode.HALF_UP);
    }

    private String normalizeDeviceCode(String deviceCode) {
        String normalized = deviceCode == null ? "" : deviceCode.trim().toUpperCase();
        if (!DEVICE_CODE_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.DEVICE_CODE_INVALID);
        }

        return normalized;
    }

    private OperationsReviewRequestStatus parseOptionalOperationsReviewStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }

        try {
            return OperationsReviewRequestStatus.valueOf(status.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "status is invalid.");
        }
    }

    private OperationsReviewRequestType parseOptionalOperationsReviewType(String type) {
        if (type == null || type.isBlank()) {
            return null;
        }

        try {
            return OperationsReviewRequestType.valueOf(type.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "type is invalid.");
        }
    }

    private String normalizeId(String id, String field) {
        String normalized = id == null ? "" : id.trim();
        if (!BUSINESS_ID_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }

        return normalized;
    }

    private String normalizeAuditTarget(String value) {
        String normalized = value == null ? "" : value.trim();
        return normalized.isBlank() ? null : normalized;
    }

    private String normalizeAuditDeviceCode(String value) {
        String normalized = normalizeAuditTarget(value);
        return normalized == null ? null : normalized.toUpperCase(Locale.ROOT);
    }

    private String resolveDeviceIdByCode(String deviceCode) {
        if (deviceCode == null) {
            return null;
        }

        try {
            return archiveRepository.findByCode(deviceCode)
                    .map(DeviceArchive::id)
                    .orElse(null);
        } catch (RuntimeException exception) {
            return null;
        }
    }

    private String resolveDeviceCodeById(String deviceId) {
        if (deviceId == null) {
            return null;
        }

        try {
            return archiveRepository.findById(deviceId)
                    .map(DeviceArchive::deviceCode)
                    .orElse(deviceId);
        } catch (RuntimeException exception) {
            return deviceId;
        }
    }

    private String resolveFaultReportTargetNo(String faultReportId) {
        if (faultReportId == null) {
            return null;
        }

        try {
            return operationsRepository.findFaultReportByIdOrNo(faultReportId)
                    .map(FaultReportRecord::faultReportNo)
                    .orElse(faultReportId);
        } catch (RuntimeException exception) {
            return faultReportId;
        }
    }

    private String resolveRepairTaskTargetNo(String repairTaskId) {
        if (repairTaskId == null) {
            return null;
        }

        try {
            return operationsRepository.findRepairTaskByIdOrNo(repairTaskId)
                    .map(RepairTaskRecord::repairTaskNo)
                    .orElse(repairTaskId);
        } catch (RuntimeException exception) {
            return repairTaskId;
        }
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

    private boolean hasPermission(AuthenticatedUser user, PermissionCode permission) {
        return user.permissions() != null && user.permissions().contains(permission);
    }

    private boolean isHighSeverity(FaultSeverity severity) {
        return severity == FaultSeverity.EMERGENCY || severity == FaultSeverity.SEVERE;
    }

    private boolean requiresReinspection(FaultSeverity severity, RepairReportResult result) {
        if (result == RepairReportResult.UNRESOLVED) {
            return false;
        }

        if (result == RepairReportResult.TEMPORARY_RESTORED) {
            return !isHighSeverity(severity);
        }

        return result == RepairReportResult.REPAIRED && isHighSeverity(severity);
    }

    private FaultStatus nextFaultStatus(FaultSeverity severity, RepairReportResult result) {
        if (result == RepairReportResult.UNRESOLVED
                || (result == RepairReportResult.TEMPORARY_RESTORED && isHighSeverity(severity))) {
            return FaultStatus.PENDING_ACCEPTANCE;
        }

        if (requiresReinspection(severity, result)) {
            return FaultStatus.PENDING_REINSPECTION;
        }

        return FaultStatus.CLOSED;
    }

    private String nextDeviceStatus(FaultStatus nextFaultStatus) {
        return switch (nextFaultStatus) {
            case PENDING_ACCEPTANCE -> "FAULTED";
            case PENDING_REINSPECTION -> "PENDING_REINSPECTION";
            case CLOSED -> "NORMAL";
            default -> "NORMAL";
        };
    }

    private String formatWorkloadStatus(RepairerWorkloadStatus status) {
        return switch (status) {
            case IDLE -> "空闲";
            case LOW_LOAD -> "低负载";
            case MEDIUM_LOAD -> "中负载";
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
