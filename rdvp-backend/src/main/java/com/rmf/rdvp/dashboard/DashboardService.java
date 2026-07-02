package com.rmf.rdvp.dashboard;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.archive.DeviceArchiveRepository;
import com.rmf.rdvp.archive.DeviceArchiveRequestRepository;
import com.rmf.rdvp.archive.DeviceArchiveRequestType;
import com.rmf.rdvp.archive.DeviceVerificationReportRepository;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogRepository;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.operations.OperationsRepository;

@Service
public class DashboardService {

    private final DeviceArchiveRepository archiveRepository;
    private final DeviceArchiveRequestRepository archiveRequestRepository;
    private final DeviceVerificationReportRepository verificationRepository;
    private final OperationsRepository operationsRepository;
    private final AuditLogRepository auditLogRepository;

    public DashboardService(
            DeviceArchiveRepository archiveRepository,
            DeviceArchiveRequestRepository archiveRequestRepository,
            DeviceVerificationReportRepository verificationRepository,
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
                reviewStats(user),
                logStats(user));
    }

    private ArchiveDashboardStats archiveStats() {
        return new ArchiveDashboardStats(
                archiveRepository.countActiveDevices(),
                archiveRequestRepository.countApprovedByType(DeviceArchiveRequestType.CREATE),
                archiveRequestRepository.countApprovedByType(DeviceArchiveRequestType.DELETE),
                archiveRequestRepository.countApprovedByType(DeviceArchiveRequestType.UPDATE),
                auditLogRepository.countSuccessByAction(AuditAction.DEVICE_ARCHIVE_QUERY),
                auditLogRepository.countSuccessByAction(AuditAction.DEVICE_ARCHIVE_EXPORT));
    }

    private OperationsDashboardStats operationsStats() {
        return new OperationsDashboardStats(
                operationsRepository.countTaskPoolItems(),
                verificationRepository.countAll(),
                operationsRepository.countFaultReports(),
                operationsRepository.countRepairReports(),
                operationsRepository.countReinspectionReports());
    }

    private ReviewDashboardStats reviewStats(AuthenticatedUser user) {
        boolean canViewReviewedTotal = hasAnyPermission(
                user,
                PermissionCode.LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY,
                PermissionCode.LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY);
        boolean canViewPendingArchiveReviews = hasPermission(user, PermissionCode.REVIEW_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW);
        boolean canViewPendingOperationsReviews = hasPermission(user, PermissionCode.REVIEW_CENTER_OPERATIONS_REVIEW);
        if (!canViewReviewedTotal && !canViewPendingArchiveReviews && !canViewPendingOperationsReviews) {
            return null;
        }

        return new ReviewDashboardStats(
                canViewReviewedTotal ? archiveRequestRepository.countReviewed() + operationsRepository.countReviewedOperationsReviews() : null,
                canViewPendingArchiveReviews ? archiveRequestRepository.countPendingReview() : null,
                canViewPendingOperationsReviews ? operationsRepository.countPendingOperationsReviews() : null);
    }

    private LogDashboardStats logStats(AuthenticatedUser user) {
        Long archiveOperationLogs = hasPermission(user, PermissionCode.LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY)
                ? archiveOperationLogCount()
                : null;
        Long archiveReviewLogs = hasPermission(user, PermissionCode.LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY)
                ? archiveReviewLogCount()
                : null;
        Long operationsOperationLogs = hasPermission(user, PermissionCode.LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY)
                ? operationsOperationLogCount()
                : null;
        Long operationsReviewLogs = hasPermission(user, PermissionCode.LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY)
                ? operationsReviewLogCount()
                : null;
        if (archiveOperationLogs == null && archiveReviewLogs == null
                && operationsOperationLogs == null && operationsReviewLogs == null) {
            return null;
        }

        return new LogDashboardStats(
                safeCount(archiveOperationLogs)
                        + safeCount(archiveReviewLogs)
                        + safeCount(operationsOperationLogs)
                        + safeCount(operationsReviewLogs),
                archiveOperationLogs,
                archiveReviewLogs,
                operationsOperationLogs,
                operationsReviewLogs);
    }

    private long archiveOperationLogCount() {
        return archiveRequestRepository.countAll()
                + auditLogRepository.countSuccessByAction(AuditAction.DEVICE_ARCHIVE_QUERY)
                + auditLogRepository.countSuccessByAction(AuditAction.DEVICE_ARCHIVE_EXPORT);
    }

    private long archiveReviewLogCount() {
        return archiveRequestRepository.countReviewed();
    }

    private long operationsOperationLogCount() {
        return verificationRepository.countAll()
                + operationsRepository.countFaultReports()
                + operationsRepository.countRepairTasks()
                + operationsRepository.countRepairReports()
                + operationsRepository.countReinspectionReports();
    }

    private long operationsReviewLogCount() {
        return operationsRepository.countReviewedOperationsReviews();
    }

    private boolean canViewArchiveStats(AuthenticatedUser user) {
        return hasAnyPermission(
                user,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT,
                PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT);
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

    private long safeCount(Long value) {
        return value == null ? 0 : value;
    }
}
