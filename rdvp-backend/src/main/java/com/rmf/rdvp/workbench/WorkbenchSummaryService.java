package com.rmf.rdvp.workbench;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.archive.DeviceChangeRequestRepository;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.operations.OperationsRepository;

@Service
public class WorkbenchSummaryService {

    private final DeviceChangeRequestRepository changeRequestRepository;
    private final OperationsRepository operationsRepository;

    public WorkbenchSummaryService(
            DeviceChangeRequestRepository changeRequestRepository,
            OperationsRepository operationsRepository) {
        this.changeRequestRepository = changeRequestRepository;
        this.operationsRepository = operationsRepository;
    }

    public WorkbenchSummary getSummary(AuthenticatedUser user) {
        return new WorkbenchSummary(
                hasPermission(user, PermissionCode.MGMT_ARCHIVE_CHANGE_REVIEW)
                        ? changeRequestRepository.countPendingReview()
                        : 0,
                hasPermission(user, PermissionCode.OPS_REPAIR_TASK_ACCEPT)
                        ? operationsRepository.countPendingAcceptanceFaults()
                        : 0,
                hasPermission(user, PermissionCode.OPS_REPAIR_REPORT_CREATE)
                        ? operationsRepository.countActiveRepairTasksByMaintainer(user.id())
                        : 0,
                hasPermission(user, PermissionCode.OPS_REINSPECTION_CREATE)
                        ? operationsRepository.countPendingReinspections()
                        : 0,
                0);
    }

    private boolean hasPermission(AuthenticatedUser user, PermissionCode permission) {
        return user != null && user.permissions().contains(permission);
    }
}
