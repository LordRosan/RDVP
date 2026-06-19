package com.rmf.rdvp.dashboard;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.archive.DeviceArchiveRepository;
import com.rmf.rdvp.archive.DeviceArchiveRequestRepository;
import com.rmf.rdvp.archive.DeviceArchiveRequestType;
import com.rmf.rdvp.archive.DeviceVerificationRepository;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogRepository;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.operations.OperationsRepository;

@Service
public class DashboardService {

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceArchiveRequestRepository archiveRequestRepository;
    private final DeviceVerificationRepository verificationRepository;
    private final OperationsRepository operationsRepository;
    private final AuditLogRepository auditLogRepository;

    public DashboardService(
            DeviceArchiveRepository archiveRepository,
            DeviceArchiveRequestRepository archiveRequestRepository,
            DeviceVerificationRepository verificationRepository,
            OperationsRepository operationsRepository,
            AuditLogRepository auditLogRepository) {
        this.archiveRepository = archiveRepository;
        this.archiveRequestRepository = archiveRequestRepository;
        this.verificationRepository = verificationRepository;
        this.operationsRepository = operationsRepository;
        this.auditLogRepository = auditLogRepository;
    }

    public DashboardSnapshot snapshot(AuthenticatedUser user) {
        return new DashboardSnapshot(
                canViewArchiveStats(user) ? archiveStats() : null,
                canViewOperationsStats(user) ? operationsStats() : null,
                managementStats(user));
    }

    private ArchiveDashboardStats archiveStats() {
        return new ArchiveDashboardStats(
                archiveRepository.countActiveDevices(),
                archiveRequestRepository.countApprovedByType(DeviceArchiveRequestType.CREATE),
                archiveRequestRepository.countApprovedByType(DeviceArchiveRequestType.DELETE),
                archiveRequestRepository.countApprovedByType(DeviceArchiveRequestType.UPDATE),
                auditLogRepository.countSuccessByAction(AuditAction.DEVICE_ARCHIVE_QUERY));
    }

    private OperationsDashboardStats operationsStats() {
        return new OperationsDashboardStats(
                operationsRepository.countTaskPoolItems(),
                verificationRepository.countAll(),
                operationsRepository.countFaultReports(),
                operationsRepository.countRepairReports(),
                operationsRepository.countReinspectionRecords());
    }

    private ManagementDashboardStats managementStats(AuthenticatedUser user) {
        boolean canViewReviewedTotal = hasPermission(user, PermissionCode.MANAGEMENT_CENTER_REVIEW_RECORD_QUERY);
        boolean canViewPendingArchiveReviews = hasPermission(user, PermissionCode.MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW);
        boolean canViewPendingOperationsReviews = hasPermission(user, PermissionCode.MANAGEMENT_CENTER_OPERATIONS_REVIEW);
        if (!canViewReviewedTotal && !canViewPendingArchiveReviews && !canViewPendingOperationsReviews) {
            return null;
        }

        return new ManagementDashboardStats(
                canViewReviewedTotal ? archiveRequestRepository.countReviewed() : null,
                canViewPendingArchiveReviews ? archiveRequestRepository.countPendingReview() : null,
                canViewPendingOperationsReviews ? 0L : null);
    }

    private boolean canViewArchiveStats(AuthenticatedUser user) {
        return hasAnyPermission(
                user,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QR_CODE_EXPORT);
    }

    private boolean canViewOperationsStats(AuthenticatedUser user) {
        return hasAnyPermission(
                user,
                PermissionCode.OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT,
                PermissionCode.OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT,
                PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT,
                PermissionCode.OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT,
                PermissionCode.OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT,
                PermissionCode.OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT);
    }

    private boolean hasAnyPermission(AuthenticatedUser user, PermissionCode... permissions) {
        for (PermissionCode permission : permissions) {
            if (hasPermission(user, permission)) {
                return true;
            }
        }

        return false;
    }

    private boolean hasPermission(AuthenticatedUser user, PermissionCode permission) {
        return user != null && user.permissions().contains(permission);
    }
}
