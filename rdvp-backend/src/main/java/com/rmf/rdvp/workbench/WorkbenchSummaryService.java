package com.rmf.rdvp.workbench;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.archive.DeviceArchiveRequestRepository;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.operations.OperationsRepository;

@Service
public class WorkbenchSummaryService {

    private final DeviceArchiveRequestRepository archiveRequestRepository;
    private final OperationsRepository operationsRepository;

    public WorkbenchSummaryService(
            DeviceArchiveRequestRepository archiveRequestRepository,
            OperationsRepository operationsRepository) {
        this.archiveRequestRepository = archiveRequestRepository;
        this.operationsRepository = operationsRepository;
    }

    public WorkbenchSummary getSummary(AuthenticatedUser user) {
        return new WorkbenchSummary(
                hasPermission(user, PermissionCode.MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW)
                        ? archiveRequestRepository.countPendingReview()
                        : 0,
                hasPermission(user, PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT)
                        ? operationsRepository.countPendingAcceptanceFaults()
                        : 0,
                hasPermission(user, PermissionCode.OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT)
                        ? operationsRepository.countActiveRepairTasksByMaintainer(user.id())
                        : 0,
                hasPermission(user, PermissionCode.OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT)
                        ? operationsRepository.countPendingReinspections()
                        : 0);
    }

    private boolean hasPermission(AuthenticatedUser user, PermissionCode permission) {
        return user != null && user.permissions().contains(permission);
    }
}


