package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import com.rmf.rdvp.archive.DeviceArchive;
import com.rmf.rdvp.archive.DeviceArchiveRepository;

@Repository
@Profile("test")
public class InMemoryOperationsRepository implements OperationsRepository {

    private final Map<String, FaultReportRecord> faultReportsById = new ConcurrentHashMap<>();
    private final Map<String, RepairTaskRecord> repairTasksById = new ConcurrentHashMap<>();
    private final Map<String, RepairReportRecord> repairReportsById = new ConcurrentHashMap<>();
    private final Map<String, ReinspectionRecordCreate> reinspectionRecordsById = new ConcurrentHashMap<>();
    private final Map<String, OperationReviewRequest> operationReviewsById = new ConcurrentHashMap<>();
    private final DeviceArchiveRepository archiveRepository;

    public InMemoryOperationsRepository(DeviceArchiveRepository archiveRepository) {
        this.archiveRepository = archiveRepository;
    }

    @Override
    public void createFaultReport(FaultReportCreate create) {
        faultReportsById.put(create.id(), new FaultReportRecord(
                create.id(),
                create.faultReportNo(),
                create.deviceId(),
                create.reporterId(),
                create.faultType(),
                create.severity(),
                FaultStatus.PENDING_ACCEPTANCE,
                create.description(),
                create.sceneCondition(),
                create.occurredAt(),
                create.longitude(),
                create.latitude(),
                null,
                create.createdAt(),
                create.createdAt()));
    }

    @Override
    public Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo) {
        return faultReportsById.values()
                .stream()
                .filter(item -> item.id().equals(idOrNo) || item.faultReportNo().equals(idOrNo))
                .findFirst();
    }

    @Override
    public boolean hasActiveFaultForDevice(String deviceId) {
        return faultReportsById.values()
                .stream()
                .anyMatch(item -> item.deviceId().equals(deviceId) && item.status() != FaultStatus.CLOSED);
    }

    @Override
    public List<TaskAcceptanceItem> listTaskAcceptance(
            FaultSeverity severity,
            int radiusKm,
            BigDecimal longitude,
            BigDecimal latitude,
            boolean includeRepairTasks,
            boolean includeReinspectionTasks,
            int limit) {
        return faultReportsById.values()
                .stream()
                .filter(item -> (includeRepairTasks && item.status() == FaultStatus.PENDING_ACCEPTANCE)
                        || (includeReinspectionTasks && item.status() == FaultStatus.PENDING_REINSPECTION
                        && !hasActiveReinspectionTaskForFault(item.id())))
                .filter(item -> severity == null || item.severity() == severity)
                .map(item -> toTaskAcceptanceItem(item, longitude, latitude))
                .filter(item -> item.distanceKm() == null || item.distanceKm().compareTo(BigDecimal.valueOf(radiusKm)) <= 0)
                .sorted(Comparator.comparing(TaskAcceptanceItem::submittedAt).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public long countPendingAcceptanceFaults() {
        return faultReportsById.values()
                .stream()
                .filter(item -> item.status() == FaultStatus.PENDING_ACCEPTANCE)
                .count();
    }

    @Override
    public long countTaskPoolItems() {
        long pendingReinspectionPoolItems = faultReportsById.values()
                .stream()
                .filter(item -> item.status() == FaultStatus.PENDING_REINSPECTION)
                .filter(item -> !hasActiveReinspectionTaskForFault(item.id()))
                .count();
        return countPendingAcceptanceFaults() + pendingReinspectionPoolItems;
    }

    @Override
    public long countFaultReports() {
        return faultReportsById.size();
    }

    @Override
    public boolean hasActiveRepairTaskForFault(String faultReportId) {
        return repairTasksById.values()
                .stream()
                .anyMatch(item -> item.faultReportId().equals(faultReportId)
                        && item.status() != RepairTaskStatus.REPORT_SUBMITTED);
    }

    @Override
    public boolean hasActiveReinspectionTaskForFault(String faultReportId) {
        // In-memory implementation: reinspection tasks share the repairTasksById map.
        // The real implementation uses task_type column.
        return repairTasksById.values()
                .stream()
                .anyMatch(item -> item.faultReportId().equals(faultReportId)
                        && (item.status() == RepairTaskStatus.ACCEPTED || item.status() == RepairTaskStatus.PROCESSING));
    }

    @Override
    public int countActiveRepairTasksByMaintainer(String maintainerId) {
        return (int) repairTasksById.values()
                .stream()
                .filter(item -> item.maintainerId().equals(maintainerId))
                .filter(item -> item.status() == RepairTaskStatus.ACCEPTED || item.status() == RepairTaskStatus.PROCESSING)
                .count();
    }

    @Override
    public void createRepairTask(RepairTaskCreate create) {
        FaultReportRecord fault = faultReportsById.get(create.faultReportId());
        repairTasksById.put(create.id(), new RepairTaskRecord(
                create.id(),
                create.repairTaskNo(),
                create.faultReportId(),
                fault.deviceId(),
                create.maintainerId(),
                fault.severity(),
                RepairTaskStatus.ACCEPTED,
                create.acceptedLongitude(),
                create.acceptedLatitude(),
                create.acceptedAt(),
                null));
    }

    @Override
    public boolean markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt) {
        FaultReportRecord fault = faultReportsById.get(faultReportId);
        if (fault == null || fault.status() != FaultStatus.PENDING_ACCEPTANCE || fault.acceptedTaskId() != null) {
            return false;
        }

        faultReportsById.put(faultReportId, new FaultReportRecord(
                fault.id(),
                fault.faultReportNo(),
                fault.deviceId(),
                fault.reporterId(),
                fault.faultType(),
                fault.severity(),
                FaultStatus.ACCEPTED,
                fault.description(),
                fault.sceneCondition(),
                fault.occurredAt(),
                fault.longitude(),
                fault.latitude(),
                repairTaskId,
                fault.createdAt(),
                updatedAt));
        return true;
    }

    @Override
    public List<RepairTaskItem> listRepairTasks(String maintainerId, int limit) {
        return repairTasksById.values()
                .stream()
                .filter(item -> item.maintainerId().equals(maintainerId))
                .filter(item -> item.status() != RepairTaskStatus.REPORT_SUBMITTED)
                .sorted(Comparator.comparing(RepairTaskRecord::acceptedAt).reversed())
                .limit(limit)
                .map(this::toRepairTaskItem)
                .toList();
    }

    @Override
    public Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo) {
        return repairTasksById.values()
                .stream()
                .filter(item -> item.id().equals(idOrNo) || item.repairTaskNo().equals(idOrNo))
                .findFirst();
    }

    @Override
    public List<ReinspectionTaskSummary> listPendingReinspections(int limit) {
        return faultReportsById.values()
                .stream()
                .filter(item -> item.status() == FaultStatus.PENDING_REINSPECTION)
                .sorted(Comparator.comparing(FaultReportRecord::updatedAt).reversed())
                .limit(limit)
                .map(this::toReinspectionTask)
                .toList();
    }

    @Override
    public long countPendingReinspections() {
        return faultReportsById.values()
                .stream()
                .filter(item -> item.status() == FaultStatus.PENDING_REINSPECTION)
                .count();
    }

    @Override
    public void createRepairReport(RepairReportCreate create) {
        repairReportsById.put(create.id(), new RepairReportRecord(
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
                create.createdAt()));
    }

    @Override
    public long countRepairReports() {
        return repairReportsById.size();
    }

    @Override
    public Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId) {
        return repairReportsById.values()
                .stream()
                .filter(item -> item.faultReportId().equals(faultReportId))
                .max(Comparator.comparing(RepairReportRecord::createdAt));
    }

    @Override
    public boolean markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt) {
        RepairTaskRecord task = repairTasksById.get(repairTaskId);
        if (task == null || (task.status() != RepairTaskStatus.ACCEPTED && task.status() != RepairTaskStatus.PROCESSING)) {
            return false;
        }

        repairTasksById.put(repairTaskId, new RepairTaskRecord(
                task.id(),
                task.repairTaskNo(),
                task.faultReportId(),
                task.deviceId(),
                task.maintainerId(),
                task.severity(),
                RepairTaskStatus.REPORT_SUBMITTED,
                task.acceptedLongitude(),
                task.acceptedLatitude(),
                task.acceptedAt(),
                completedAt));
        return true;
    }

    @Override
    public boolean markReinspectionTaskReported(String faultReportId, OffsetDateTime completedAt) {
        Optional<RepairTaskRecord> task = repairTasksById.values()
                .stream()
                .filter(item -> item.faultReportId().equals(faultReportId)
                        && (item.status() == RepairTaskStatus.ACCEPTED || item.status() == RepairTaskStatus.PROCESSING))
                .findFirst();
        if (task.isEmpty()) {
            return false;
        }
        RepairTaskRecord t = task.get();
        repairTasksById.put(t.id(), new RepairTaskRecord(
                t.id(),
                t.repairTaskNo(),
                t.faultReportId(),
                t.deviceId(),
                t.maintainerId(),
                t.severity(),
                RepairTaskStatus.REPORT_SUBMITTED,
                t.acceptedLongitude(),
                t.acceptedLatitude(),
                t.acceptedAt(),
                completedAt));
        return true;
    }

    @Override
    public boolean updateFaultStatusIfCurrent(
            String faultReportId,
            FaultStatus expectedStatus,
            FaultStatus status,
            OffsetDateTime updatedAt) {
        FaultReportRecord fault = faultReportsById.get(faultReportId);
        if (fault == null || fault.status() != expectedStatus) {
            return false;
        }

        faultReportsById.put(faultReportId, new FaultReportRecord(
                fault.id(),
                fault.faultReportNo(),
                fault.deviceId(),
                fault.reporterId(),
                fault.faultType(),
                fault.severity(),
                status,
                fault.description(),
                fault.sceneCondition(),
                fault.occurredAt(),
                fault.longitude(),
                fault.latitude(),
                status == FaultStatus.PENDING_ACCEPTANCE ? null : fault.acceptedTaskId(),
                fault.createdAt(),
                updatedAt));
        return true;
    }

    @Override
    public void createReinspectionRecord(ReinspectionRecordCreate create) {
        reinspectionRecordsById.put(create.id(), create);
    }

    @Override
    public long countReinspectionRecords() {
        return reinspectionRecordsById.size();
    }

    @Override
    public void createOperationReviewRequest(OperationReviewRequestCreate create) {
        DeviceArchive device = archiveRepository.findById(create.deviceId()).orElseThrow();
        operationReviewsById.put(create.id(), new OperationReviewRequest(
                create.id(),
                create.type(),
                create.targetId(),
                create.targetNo(),
                create.faultReportId(),
                create.deviceId(),
                device.deviceCode(),
                device.name(),
                create.applicantId(),
                create.applicantId(),
                create.summary(),
                OperationReviewRequestStatus.PENDING_REVIEW,
                create.submittedAt(),
                null,
                null,
                null));
    }

    @Override
    public Optional<OperationReviewRequest> findOperationReviewRequestById(String id) {
        return Optional.ofNullable(operationReviewsById.get(id));
    }

    @Override
    public OperationReviewRequestPage listOperationReviewRequests(
            OperationReviewRequestStatus status,
            OperationReviewRequestType type,
            String keyword,
            int limit,
            int offset) {
        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase();
        List<OperationReviewRequest> items = operationReviewsById.values()
                .stream()
                .filter(item -> status == null || item.status() == status)
                .filter(item -> type == null || item.type() == type)
                .filter(item -> normalizedKeyword.isBlank()
                        || item.deviceCode().toLowerCase().contains(normalizedKeyword)
                        || item.deviceName().toLowerCase().contains(normalizedKeyword)
                        || item.targetNo().toLowerCase().contains(normalizedKeyword))
                .sorted(Comparator.comparing(OperationReviewRequest::submittedAt).reversed())
                .toList();
        List<OperationReviewRequest> page = items.stream()
                .skip(offset)
                .limit(limit)
                .toList();
        return new OperationReviewRequestPage(page, items.size());
    }

    @Override
    public boolean markOperationReviewRequestReviewed(
            String id,
            OperationReviewRequestStatus status,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt) {
        OperationReviewRequest request = operationReviewsById.get(id);
        if (request == null || request.status() != OperationReviewRequestStatus.PENDING_REVIEW) {
            return false;
        }

        operationReviewsById.put(id, new OperationReviewRequest(
                request.id(),
                request.type(),
                request.targetId(),
                request.targetNo(),
                request.faultReportId(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                request.summary(),
                status,
                request.submittedAt(),
                reviewerId,
                reviewComment,
                reviewedAt));
        return true;
    }

    @Override
    public long countPendingOperationReviews() {
        return operationReviewsById.values()
                .stream()
                .filter(item -> item.status() == OperationReviewRequestStatus.PENDING_REVIEW)
                .count();
    }

    @Override
    public long countReviewedOperationReviews() {
        return operationReviewsById.values()
                .stream()
                .filter(item -> item.status() == OperationReviewRequestStatus.APPROVED
                        || item.status() == OperationReviewRequestStatus.REJECTED)
                .count();
    }

    private TaskAcceptanceItem toTaskAcceptanceItem(FaultReportRecord fault, BigDecimal longitude, BigDecimal latitude) {
        DeviceArchive device = archiveRepository.findById(fault.deviceId()).orElseThrow();
        return new TaskAcceptanceItem(
                fault.id(),
                fault.id(),
                fault.faultReportNo(),
                device.deviceCode(),
                device.name(),
                fault.faultType(),
                fault.severity(),
                calculateDistanceKm(longitude, latitude, device.longitude(), device.latitude()),
                new TaskAcceptanceItem.DeviceLocation(device.address(), device.longitude(), device.latitude()),
                fault.createdAt(),
                RepairTaskStatus.AVAILABLE,
                fault.status() == FaultStatus.PENDING_REINSPECTION ? "REINSPECTION" : "REPAIR");
    }

    private BigDecimal calculateDistanceKm(
            BigDecimal sourceLongitude,
            BigDecimal sourceLatitude,
            BigDecimal targetLongitude,
            BigDecimal targetLatitude) {
        if (sourceLongitude == null || sourceLatitude == null || targetLongitude == null || targetLatitude == null) {
            return null;
        }

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

    private RepairTaskItem toRepairTaskItem(RepairTaskRecord task) {
        FaultReportRecord fault = faultReportsById.get(task.faultReportId());
        DeviceArchive device = archiveRepository.findById(task.deviceId()).orElseThrow();
        return new RepairTaskItem(
                task.id(),
                task.repairTaskNo(),
                fault.faultReportNo(),
                device.deviceCode(),
                device.name(),
                fault.faultType(),
                fault.severity(),
                task.acceptedAt(),
                task.status());
    }

    private ReinspectionTaskSummary toReinspectionTask(FaultReportRecord fault) {
        DeviceArchive device = archiveRepository.findById(fault.deviceId()).orElseThrow();
        OffsetDateTime repairedAt = findLatestRepairReportByFaultReportId(fault.id())
                .map(RepairReportRecord::repairedAt)
                .orElse(null);
        return new ReinspectionTaskSummary(
                fault.id(),
                fault.id(),
                fault.faultReportNo(),
                device.deviceCode(),
                device.name(),
                fault.severity(),
                new TaskAcceptanceItem.DeviceLocation(device.address(), device.longitude(), device.latitude()),
                repairedAt,
                fault.status());
    }
}
