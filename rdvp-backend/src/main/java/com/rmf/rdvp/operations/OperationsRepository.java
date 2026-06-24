package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface OperationsRepository {

    void createFaultReport(FaultReportCreate create);

    Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo);

    boolean hasActiveFaultForDevice(String deviceId);

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

    boolean hasActiveRepairTaskForFault(String faultReportId);

    boolean hasActiveReinspectionTaskForFault(String faultReportId);

    int countActiveRepairTasksByMaintainer(String maintainerId);

    void createRepairTask(RepairTaskCreate create);

    boolean markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt);

    List<RepairTaskItem> listRepairTasks(String maintainerId, int limit);

    Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo);

    List<ReinspectionTaskSummary> listPendingReinspections(int limit);

    long countPendingReinspections();

    void createRepairReport(RepairReportCreate create);

    long countRepairReports();

    Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId);

    boolean markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt);

    boolean markReinspectionTaskReported(String faultReportId, OffsetDateTime completedAt);

    boolean updateFaultStatusIfCurrent(
            String faultReportId,
            FaultStatus expectedStatus,
            FaultStatus status,
            OffsetDateTime updatedAt);

    void createReinspectionRecord(ReinspectionRecordCreate create);

    long countReinspectionRecords();

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
            String reviewOperatorId,
            String reviewComment,
            OffsetDateTime reviewedAt);

    long countPendingOperationsReviews();

    long countReviewedOperationsReviews();
}
