import { AppTone } from '../../shared/theme/AppTheme';
import {
  ArchiveDashboardStats,
  LogDashboardStats,
  OperationsDashboardStats,
  HomeAction,
  HomeActionId,
  HomeDashboard,
  ReviewDashboardStats
} from '../models/HomeModels';
import { ApiResponse } from '../../shared/models/ApiModels';
import {
  ArchiveCenterPermissions,
  LogCenterPermissions,
  OperationsCenterPermissions,
  PermissionCode,
  ReviewCenterPermissions
} from '../../user/models/PermissionModels';
import { SessionStore } from '../../user/stores/SessionStore';
import { ApiClient } from '../../shared/services/ApiClient';
import { AppRoutes } from '../../shared/navigation/AppRoutes';

export class HomeService {
  static getVerificationReportRoute(): string {
    return AppRoutes.VerificationReportPage;
  }

  static getFaultReportRoute(): string {
    return AppRoutes.FaultReportPage;
  }

  static getRepairAndReinspectionRoute(): string {
    return AppRoutes.RepairAndReinspectionPage;
  }

  static getEmptyDashboard(): HomeDashboard {
    return {};
  }

  static async fetchDashboardRemoteFirst(): Promise<ApiResponse<HomeDashboard>> {
    const response = await ApiClient.request<HomeDashboard>(`/api/v1/home/dashboard?_=${Date.now()}`, 'GET', true);
    if (!response.success || response.data === undefined) {
      return response;
    }

    return {
      success: true,
      data: HomeService.normalizeDashboard(response.data),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static getActions(): HomeAction[] {
    const actions: HomeAction[] = [];

    if (HomeService.canAccessArchiveCenter()) {
      actions.push({
        id: HomeActionId.ArchiveCenter,
        title: '档案中心',
        tone: AppTone.Primary
      });
    }

    if (HomeService.canAccessOperationsCenter()) {
      actions.push({
        id: HomeActionId.OperationsCenter,
        title: '运维中心',
        tone: AppTone.Success
      });
    }

    if (HomeService.canAccessReviewCenter()) {
      actions.push({
        id: HomeActionId.ReviewCenter,
        title: '审核中心',
        tone: AppTone.Warning
      });
    }

    if (HomeService.canAccessLogCenter()) {
      actions.push({
        id: HomeActionId.LogCenter,
        title: '日志中心',
        tone: AppTone.Log
      });
    }

    return actions;
  }

  static getArchiveCenterActions(): HomeAction[] {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveQuery)) {
      return [];
    }

    const actions: HomeAction[] = [{
      id: HomeActionId.ArchiveQuery,
      title: '查询档案',
      tone: AppTone.Primary
    }];

    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveCreateRequestSubmit)) {
      actions.push({
        id: HomeActionId.ArchiveCreateRequest,
        title: '添加档案',
        tone: AppTone.Primary
      });
    }

    return actions;
  }

  static getOperationsCenterActions(): HomeAction[] {
    const actions: HomeAction[] = [];

    if (SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceVerificationSubmit)) {
      actions.push(HomeService.createAction(HomeActionId.VerificationAndFaultReport, '核验与报修', AppTone.Success));
    }

    if (HomeService.canAcceptAnyOperationTask()) {
      actions.push(HomeService.createAction(HomeActionId.TaskAcceptance, '任务接取', AppTone.Success));
    }

    if (HomeService.canSubmitAnyOperationReport()) {
      actions.push(HomeService.createAction(HomeActionId.RepairAndReinspection, '维修与复检', AppTone.Success));
    }

    return actions;
  }

  static getReviewCenterActions(): HomeAction[] {
    const actions: HomeAction[] = [];
    if (HomeService.canReviewArchiveRequest()) {
      actions.push({
        id: HomeActionId.ArchiveReview,
        title: '档案审核',
        tone: AppTone.Warning
      });
    }

    if (SessionStore.hasPermission(PermissionCode.ReviewCenterOperationsReview)) {
      actions.push({
        id: HomeActionId.OperationsReview,
        title: '运维审核',
        tone: AppTone.Warning
      });
    }

    return actions;
  }

  static getLogCenterActions(): HomeAction[] {
    const actions: HomeAction[] = [];
    if (HomeService.canQueryArchiveLogs()) {
      actions.push({
        id: HomeActionId.ArchiveLogQuery,
        title: '档案日志',
        tone: AppTone.Log
      });
    }

    if (HomeService.canQueryOperationsLogs()) {
      actions.push({
        id: HomeActionId.OperationsLogQuery,
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

  static canReviewArchiveRequest(): boolean {
    return SessionStore.hasPermission(PermissionCode.ReviewCenterArchiveRequestReview);
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

  private static createAction(id: HomeActionId, title: string, tone: AppTone): HomeAction {
    return {
      id,
      title,
      tone
    };
  }

  private static normalizeDashboard(data: HomeDashboard): HomeDashboard {
    const dashboard: HomeDashboard = {};
    if (data.archive !== undefined) {
      dashboard.archive = HomeService.normalizeArchiveStats(data.archive);
    }
    if (data.operations !== undefined) {
      dashboard.operations = HomeService.normalizeOperationsStats(data.operations);
    }
    if (data.review !== undefined) {
      dashboard.review = HomeService.normalizeReviewStats(data.review);
    }
    if (data.log !== undefined) {
      dashboard.log = HomeService.normalizeLogStats(data.log);
    }

    return dashboard;
  }

  private static normalizeArchiveStats(stats: ArchiveDashboardStats | undefined): ArchiveDashboardStats {
    return {
      deviceTotal: HomeService.toSafeCount(stats?.deviceTotal),
      archiveCreates: HomeService.toSafeCount(stats?.archiveCreates),
      archiveDeletes: HomeService.toSafeCount(stats?.archiveDeletes),
      archiveUpdates: HomeService.toSafeCount(stats?.archiveUpdates),
      archiveQueries: HomeService.toSafeCount(stats?.archiveQueries),
      archiveExports: HomeService.toSafeCount(stats?.archiveExports)
    };
  }

  private static normalizeOperationsStats(stats: OperationsDashboardStats | undefined): OperationsDashboardStats {
    return {
      taskPoolTotal: HomeService.toSafeCount(stats?.taskPoolTotal),
      verifications: HomeService.toSafeCount(stats?.verifications),
      faultReports: HomeService.toSafeCount(stats?.faultReports),
      repairs: HomeService.toSafeCount(stats?.repairs),
      reinspections: HomeService.toSafeCount(stats?.reinspections)
    };
  }

  private static normalizeReviewStats(stats: ReviewDashboardStats | undefined): ReviewDashboardStats {
    const normalized: ReviewDashboardStats = {};
    const reviewedTotal = HomeService.toSafeOptionalCount(stats?.reviewedTotal);
    if (reviewedTotal !== undefined) {
      normalized.reviewedTotal = reviewedTotal;
    }

    const pendingArchiveReviews = HomeService.toSafeOptionalCount(stats?.pendingArchiveReviews);
    if (pendingArchiveReviews !== undefined) {
      normalized.pendingArchiveReviews = pendingArchiveReviews;
    }

    const pendingOperationsReviews = HomeService.toSafeOptionalCount(stats?.pendingOperationsReviews);
    if (pendingOperationsReviews !== undefined) {
      normalized.pendingOperationsReviews = pendingOperationsReviews;
    }

    return normalized;
  }

  private static normalizeLogStats(stats: LogDashboardStats | undefined): LogDashboardStats {
    const normalized: LogDashboardStats = {
      logTotal: HomeService.toSafeCount(stats?.logTotal)
    };
    const archiveOperationLogs = HomeService.toSafeOptionalCount(stats?.archiveOperationLogs);
    if (archiveOperationLogs !== undefined) {
      normalized.archiveOperationLogs = archiveOperationLogs;
    }

    const archiveReviewLogs = HomeService.toSafeOptionalCount(stats?.archiveReviewLogs);
    if (archiveReviewLogs !== undefined) {
      normalized.archiveReviewLogs = archiveReviewLogs;
    }

    const operationsOperationLogs = HomeService.toSafeOptionalCount(stats?.operationsOperationLogs);
    if (operationsOperationLogs !== undefined) {
      normalized.operationsOperationLogs = operationsOperationLogs;
    }

    const operationsReviewLogs = HomeService.toSafeOptionalCount(stats?.operationsReviewLogs);
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


