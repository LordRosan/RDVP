package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface OperationsRepository {

    void createFaultReport(FaultReportCreate create);

    Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo);

    boolean hasActiveFaultForDevice(String deviceId);

    boolean approvePendingFaultReport(String faultReportId, String faultReportNo, OffsetDateTime updatedAt);

    List<TaskAcceptanceItem> listTaskAcceptance(
            FaultSeverity severity,
            int radiusKm,
            BigDecimal longitude,
            BigDecimal latitude,
            boolean includeRepairTasks,
            boolean includeReinspectionTasks,
            int limit);

    long countPendingAcceptanceFaults();

    long countTaskPoolItems();

    long countFaultReports();

    long countRepairTasks();

    int countActiveRepairTasksByMaintainer(String maintainerId);

    void createRepairTask(RepairTaskCreate create);

    Optional<RepairTaskRecord> findAvailableRepairTaskByFaultReportId(String faultReportId, String taskType);

    boolean acceptAvailableRepairTask(
            String repairTaskId,
            String maintainerId,
            BigDecimal longitude,
            BigDecimal latitude,
            OffsetDateTime acceptedAt);

    boolean markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt);

    List<RepairTaskItem> listRepairTasks(String maintainerId, int limit);

    Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo);

    Optional<RepairTaskRecord> findActiveReinspectionTaskByFaultReportId(String faultReportId);

    List<ReinspectionTaskSummary> listPendingReinspections(int limit);

    long countPendingReinspections();

    void createRepairReport(RepairReportCreate create);

    boolean hasRepairReportForRepairTask(String repairTaskId);

    long countRepairReports();

    Optional<RepairReportRecord> findRepairReportByIdOrNo(String idOrNo);

    Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId);

    boolean markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt);

    boolean markReinspectionTaskReported(String faultReportId, OffsetDateTime completedAt);

    boolean updateFaultStatusIfCurrent(
            String faultReportId,
            FaultStatus expectedStatus,
            FaultStatus status,
            OffsetDateTime updatedAt);

    void createReinspectionReport(ReinspectionReportCreate create);

    boolean hasReinspectionReportForRepairReport(String repairReportId);

    long countReinspectionReports();

    Optional<ReinspectionReportCreate> findReinspectionReportByIdOrNo(String idOrNo);

    void createOperationsReviewRequest(OperationsReviewRequestCreate create);

    Optional<OperationsReviewRequest> findOperationsReviewRequestById(String id);

    OperationsReviewRequestPage listOperationsReviewRequests(
            OperationsReviewRequestStatus status,
            OperationsReviewRequestType type,
            String keyword,
            int limit,
            int offset);

    boolean markOperationsReviewRequestReviewed(
            String id,
            OperationsReviewRequestStatus status,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt);

    boolean updateOperationsReviewRequestTargetNo(String id, String targetNo, OffsetDateTime updatedAt);

    long countPendingOperationsReviews();

    long countReviewedOperationsReviews();
}
