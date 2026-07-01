import { AppTone } from '../../styles/AppTheme';
import {
  ArchiveDashboardStats,
  LogDashboardStats,
  OperationsDashboardStats,
  MainPageAction,
  MainPageActionId,
  MainPageDashboard,
  ReviewDashboardStats
} from '../../models/app/MainPageModels';
import { ApiResponse } from '../../models/common/ApiModels';
import {
  ArchiveCenterPermissions,
  LogCenterPermissions,
  OperationsCenterPermissions,
  PermissionCode,
  ReviewCenterPermissions
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
        tone: AppTone.Primary
      });
    }

    if (MainPageService.canAccessOperationsCenter()) {
      actions.push({
        id: MainPageActionId.OperationsCenter,
        title: '运维中心',
        tone: AppTone.Success
      });
    }

    if (MainPageService.canAccessReviewCenter()) {
      actions.push({
        id: MainPageActionId.ReviewCenter,
        title: '审核中心',
        tone: AppTone.Warning
      });
    }

    if (MainPageService.canAccessLogCenter()) {
      actions.push({
        id: MainPageActionId.LogCenter,
        title: '日志中心',
        tone: AppTone.Log
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
      tone: AppTone.Primary
    }];

    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit)) {
      actions.push({
        id: MainPageActionId.DeviceArchiveCreateRequest,
        title: '添加设备档案',
        tone: AppTone.Primary
      });
    }

    return actions;
  }

  static getOperationsCenterActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];

    if (SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceVerificationSubmit)) {
      actions.push(MainPageService.createAction(MainPageActionId.DeviceVerification, '核验与报修', AppTone.Success));
    }

    if (MainPageService.canAcceptAnyOperationTask()) {
      actions.push(MainPageService.createAction(MainPageActionId.TaskAcceptance, '任务接取', AppTone.Success));
    }

    if (MainPageService.canSubmitAnyOperationReport()) {
      actions.push(MainPageService.createAction(MainPageActionId.RepairAndReinspection, '维修与复检', AppTone.Success));
    }

    return actions;
  }

  static getReviewCenterActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];
    if (MainPageService.canReviewDeviceArchiveRequest()) {
      actions.push({
        id: MainPageActionId.DeviceArchiveReview,
        title: '档案审核',
        tone: AppTone.Warning
      });
    }

    if (SessionStore.hasPermission(PermissionCode.ReviewCenterOperationsReview)) {
      actions.push({
        id: MainPageActionId.OperationsReview,
        title: '运维审核',
        tone: AppTone.Warning
      });
    }

    return actions;
  }

  static getLogCenterActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];
    if (MainPageService.canQueryArchiveLogs()) {
      actions.push({
        id: MainPageActionId.ArchiveLogQuery,
        title: '档案日志',
        tone: AppTone.Log
      });
    }

    if (MainPageService.canQueryOperationsLogs()) {
      actions.push({
        id: MainPageActionId.OperationsLogQuery,
        title: '运维日志',
        tone: AppTone.Log
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

  static canAccessReviewCenter(): boolean {
    return SessionStore.hasAnyPermission(ReviewCenterPermissions);
  }

  static canAccessLogCenter(): boolean {
    return SessionStore.hasAnyPermission(LogCenterPermissions);
  }

  static canReviewDeviceArchiveRequest(): boolean {
    return SessionStore.hasPermission(PermissionCode.ReviewCenterDeviceArchiveRequestReview);
  }

  static canQueryAnyLog(): boolean {
    return SessionStore.hasAnyPermission(LogCenterPermissions);
  }

  static canQueryArchiveLogs(): boolean {
    return SessionStore.hasAnyPermission([
      PermissionCode.LogCenterArchiveOperationLogQuery,
      PermissionCode.LogCenterArchiveReviewLogQuery
    ]);
  }

  static canQueryOperationsLogs(): boolean {
    return SessionStore.hasAnyPermission([
      PermissionCode.LogCenterOperationsOperationLogQuery,
      PermissionCode.LogCenterOperationsReviewLogQuery
    ]);
  }

  static canAcceptAnyOperationTask(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairTaskAccept) ||
      SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionTaskAccept);
  }

  static canSubmitAnyOperationReport(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit) ||
      (SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionTaskAccept) &&
        SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionReportSubmit));
  }

  private static createAction(id: MainPageActionId, title: string, tone: AppTone): MainPageAction {
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
    if (data.review !== undefined) {
      dashboard.review = MainPageService.normalizeReviewStats(data.review);
    }
    if (data.log !== undefined) {
      dashboard.log = MainPageService.normalizeLogStats(data.log);
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

  private static normalizeReviewStats(stats: ReviewDashboardStats | undefined): ReviewDashboardStats {
    const normalized: ReviewDashboardStats = {};
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

  private static normalizeLogStats(stats: LogDashboardStats | undefined): LogDashboardStats {
    const normalized: LogDashboardStats = {
      logTotal: MainPageService.toSafeCount(stats?.logTotal)
    };
    const archiveOperationLogs = MainPageService.toSafeOptionalCount(stats?.archiveOperationLogs);
    if (archiveOperationLogs !== undefined) {
      normalized.archiveOperationLogs = archiveOperationLogs;
    }

    const archiveReviewLogs = MainPageService.toSafeOptionalCount(stats?.archiveReviewLogs);
    if (archiveReviewLogs !== undefined) {
      normalized.archiveReviewLogs = archiveReviewLogs;
    }

    const operationsOperationLogs = MainPageService.toSafeOptionalCount(stats?.operationsOperationLogs);
    if (operationsOperationLogs !== undefined) {
      normalized.operationsOperationLogs = operationsOperationLogs;
    }

    const operationsReviewLogs = MainPageService.toSafeOptionalCount(stats?.operationsReviewLogs);
    if (operationsReviewLogs !== undefined) {
      normalized.operationsReviewLogs = operationsReviewLogs;
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


