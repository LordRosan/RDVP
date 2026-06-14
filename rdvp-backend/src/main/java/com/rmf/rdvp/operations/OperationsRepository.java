package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface OperationsRepository {

    void createFaultReport(FaultReportCreate create);

    Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo);

    boolean hasActiveFaultForDevice(String deviceId);

    List<AvailableRepairTaskSummary> listAvailableRepairTasks(
            FaultSeverity severity,
            int radiusKm,
            BigDecimal longitude,
            BigDecimal latitude,
            int limit);

    long countPendingAcceptanceFaults();

    boolean hasActiveRepairTaskForFault(String faultReportId);

    boolean hasActiveReinspectionTaskForFault(String faultReportId);

    int countActiveRepairTasksByMaintainer(String maintainerId);

    void createRepairTask(RepairTaskCreate create);

    boolean markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt);

    List<MyRepairTaskSummary> listMyRepairTasks(String maintainerId, int limit);

    Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo);

    List<ReinspectionTaskSummary> listPendingReinspections(int limit);

    long countPendingReinspections();

    void createRepairReport(RepairReportCreate create);

    Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId);

    boolean markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt);

    boolean markReinspectionTaskReported(String faultReportId, OffsetDateTime completedAt);

    boolean updateFaultStatusIfCurrent(
            String faultReportId,
            FaultStatus expectedStatus,
            FaultStatus status,
            OffsetDateTime updatedAt);

    void createReinspectionRecord(ReinspectionRecordCreate create);
}
