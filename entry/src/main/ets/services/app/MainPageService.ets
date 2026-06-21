import { AppColors } from '../../styles/AppTheme';
import {
  ArchiveDashboardStats,
  ManagementDashboardStats,
  OperationsDashboardStats,
  MainPageAction,
  MainPageActionId,
  MainPageDashboard
} from '../../models/app/MainPageModels';
import { ApiResponse } from '../../models/common/ApiModels';
import {
  ArchiveCenterPermissions,
  ManagementCenterPermissions,
  ManagementCenterRecordPermissions,
  OperationsCenterPermissions,
  PermissionCode
} from '../../models/identity/PermissionModels';
import { SessionStore } from '../../stores/SessionStore';
import { ApiClient } from '../common/ApiClient';

export class MainPageService {
  static getEmptyDashboard(): MainPageDashboard {
    return {};
  }

  static async fetchDashboardRemoteFirst(): Promise<ApiResponse<MainPageDashboard>> {
    const response = await ApiClient.request<MainPageDashboard>(`/api/v1/dashboard?_=${Date.now()}`, 'GET', true);
    if (!response.success || response.data === undefined) {
      return response;
    }

    return {
      success: true,
      data: MainPageService.normalizeDashboard(response.data),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static getActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];

    if (MainPageService.canAccessArchiveCenter()) {
      actions.push({
        id: MainPageActionId.ArchiveCenter,
        title: '档案中心',
        tone: AppColors.Primary
      });
    }

    if (MainPageService.canAccessOperationsCenter()) {
      actions.push({
        id: MainPageActionId.OperationsCenter,
        title: '运维中心',
        tone: AppColors.Primary
      });
    }

    if (MainPageService.canAccessManagementCenter()) {
      actions.push({
        id: MainPageActionId.ManagementCenter,
        title: '管理中心',
        tone: AppColors.Primary
      });
    }

    return actions;
  }

  static getArchiveCenterActions(): MainPageAction[] {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      return [];
    }

    const actions: MainPageAction[] = [{
      id: MainPageActionId.DeviceArchiveQuery,
      title: '查询设备档案',
      tone: AppColors.Primary
    }];

    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit)) {
      actions.push({
        id: MainPageActionId.DeviceArchiveCreateRequest,
        title: '添加设备档案',
        tone: AppColors.Primary
      });
    }

    return actions;
  }

  static getOperationsCenterActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];

    if (SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceVerificationSubmit)) {
      actions.push(MainPageService.createAction(MainPageActionId.DeviceVerification, '核验与报修', AppColors.Primary));
    }

    if (MainPageService.canAcceptAnyOperationTask()) {
      actions.push(MainPageService.createAction(MainPageActionId.TaskAcceptance, '任务接取', AppColors.Primary));
    }

    if (SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit)) {
      actions.push(MainPageService.createAction(MainPageActionId.RepairReport, '维修任务', AppColors.Primary));
    }

    if (SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionReportSubmit)) {
      actions.push(MainPageService.createAction(MainPageActionId.ReinspectionReport, '复检任务', AppColors.Primary));
    }

    return actions;
  }

  static getManagementCenterActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];
    if (MainPageService.canReviewDeviceArchiveRequest()) {
      actions.push({
        id: MainPageActionId.DeviceArchiveReview,
        title: '档案审核',
        tone: AppColors.Primary
      });
    }

    if (SessionStore.hasPermission(PermissionCode.ManagementCenterOperationsReview)) {
      actions.push({
        id: MainPageActionId.OperationsReview,
        title: '运维审核',
        tone: AppColors.Primary
      });
    }

    if (SessionStore.hasAnyPermission(ManagementCenterRecordPermissions)) {
      actions.push({
        id: MainPageActionId.RecordQuery,
        title: '记录查询',
        tone: AppColors.Primary
      });
    }

    return actions;
  }

  static canAccessArchiveCenter(): boolean {
    return SessionStore.hasAnyPermission(ArchiveCenterPermissions);
  }

  static canAccessOperationsCenter(): boolean {
    return SessionStore.hasAnyPermission(OperationsCenterPermissions);
  }

  static canAccessManagementCenter(): boolean {
    return SessionStore.hasAnyPermission(ManagementCenterPermissions);
  }

  static canReviewDeviceArchiveRequest(): boolean {
    return SessionStore.hasPermission(PermissionCode.ManagementCenterDeviceArchiveRequestReview);
  }

  static canQueryAnyManagementRecord(): boolean {
    return SessionStore.hasAnyPermission(ManagementCenterRecordPermissions);
  }

  static canAcceptAnyOperationTask(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairTaskAccept) ||
      SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionTaskAccept);
  }

  private static createAction(id: MainPageActionId, title: string, tone: string): MainPageAction {
    return {
      id,
      title,
      tone
    };
  }

  private static normalizeDashboard(data: MainPageDashboard): MainPageDashboard {
    const dashboard: MainPageDashboard = {};
    if (data.archive !== undefined) {
      dashboard.archive = MainPageService.normalizeArchiveStats(data.archive);
    }
    if (data.operations !== undefined) {
      dashboard.operations = MainPageService.normalizeOperationsStats(data.operations);
    }
    if (data.management !== undefined) {
      dashboard.management = MainPageService.normalizeManagementStats(data.management);
    }

    return dashboard;
  }

  private static normalizeArchiveStats(stats: ArchiveDashboardStats | undefined): ArchiveDashboardStats {
    return {
      deviceTotal: MainPageService.toSafeCount(stats?.deviceTotal),
      archiveCreates: MainPageService.toSafeCount(stats?.archiveCreates),
      archiveDeletes: MainPageService.toSafeCount(stats?.archiveDeletes),
      archiveUpdates: MainPageService.toSafeCount(stats?.archiveUpdates),
      archiveQueries: MainPageService.toSafeCount(stats?.archiveQueries),
      archiveExports: MainPageService.toSafeCount(stats?.archiveExports)
    };
  }

  private static normalizeOperationsStats(stats: OperationsDashboardStats | undefined): OperationsDashboardStats {
    return {
      taskPoolTotal: MainPageService.toSafeCount(stats?.taskPoolTotal),
      verifications: MainPageService.toSafeCount(stats?.verifications),
      faultReports: MainPageService.toSafeCount(stats?.faultReports),
      repairs: MainPageService.toSafeCount(stats?.repairs),
      reinspections: MainPageService.toSafeCount(stats?.reinspections)
    };
  }

  private static normalizeManagementStats(stats: ManagementDashboardStats | undefined): ManagementDashboardStats {
    const normalized: ManagementDashboardStats = {};
    const reviewedTotal = MainPageService.toSafeOptionalCount(stats?.reviewedTotal);
    if (reviewedTotal !== undefined) {
      normalized.reviewedTotal = reviewedTotal;
    }

    const pendingArchiveReviews = MainPageService.toSafeOptionalCount(stats?.pendingArchiveReviews);
    if (pendingArchiveReviews !== undefined) {
      normalized.pendingArchiveReviews = pendingArchiveReviews;
    }

    const pendingOperationsReviews = MainPageService.toSafeOptionalCount(stats?.pendingOperationsReviews);
    if (pendingOperationsReviews !== undefined) {
      normalized.pendingOperationsReviews = pendingOperationsReviews;
    }

    return normalized;
  }

  private static toSafeCount(value: number | undefined): number {
    if (value === undefined || !Number.isFinite(value) || value < 0) {
      return 0;
    }

    return Math.floor(value);
  }

  private static toSafeOptionalCount(value: number | undefined): number | undefined {
    if (value === undefined || !Number.isFinite(value) || value < 0) {
      return undefined;
    }

    return Math.floor(value);
  }
}


