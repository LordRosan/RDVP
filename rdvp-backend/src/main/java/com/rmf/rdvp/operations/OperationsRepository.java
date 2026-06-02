package com.rmf.rdvp.operations;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface OperationsRepository {

    void createFaultReport(FaultReportCreate create);

    Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo);

    List<AvailableRepairTaskSummary> listAvailableRepairTasks(FaultSeverity severity);

    boolean hasActiveRepairTaskForFault(String faultReportId);

    int countActiveRepairTasksByMaintainer(String maintainerId);

    void createRepairTask(RepairTaskCreate create);

    void markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt);

    List<MyRepairTaskSummary> listMyRepairTasks(String maintainerId);

    Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo);

    List<ReinspectionTaskSummary> listPendingReinspections();

    void createRepairReport(RepairReportCreate create);

    Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId);

    void markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt);

    void updateFaultStatus(String faultReportId, FaultStatus status, OffsetDateTime updatedAt);

    void createReinspectionRecord(ReinspectionRecordCreate create);
}
