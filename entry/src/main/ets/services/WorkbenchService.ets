import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import {
  WorkbenchAction,
  WorkbenchActionId,
  WorkbenchMetric,
  WorkbenchStatusItem,
  WorkbenchSummary
} from '../models/WorkbenchModels';
import {
  ArchiveCenterPermissions,
  ManagementCenterPermissions,
  OperationsCenterPermissions,
  PermissionCode
} from '../models/PermissionModels';
import { ApiClient } from './ApiClient';
import { SessionStore } from '../stores/SessionStore';
import { WorkbenchRefreshStore } from '../stores/WorkbenchRefreshStore';

export class WorkbenchService {
  private static cachedSummary?: WorkbenchSummary = undefined;

  static getMetrics(): WorkbenchMetric[] {
    const summary = WorkbenchService.getSummary();
    const metrics: WorkbenchMetric[] = [];

    if (WorkbenchService.canAccessArchiveCenter()) {
      metrics.push({
        id: 'archiveCenter',
        label: '档案中心',
        value: WorkbenchService.canReviewDeviceChange() ? `${summary.pendingChangeRequests}` : '可用',
        status: WorkbenchService.canReviewDeviceChange() ? '待审核变更' : '档案查询',
        tone: AppColors.Primary
      });
    }

    if (WorkbenchService.canAccessOperationsCenter()) {
      const visibleTaskCount =
        (SessionStore.hasPermission(PermissionCode.OpsRepairTaskAccept) ? summary.availableRepairTasks : 0) +
        (SessionStore.hasPermission(PermissionCode.OpsRepairReportCreate) ? summary.activeRepairTasks : 0) +
        (SessionStore.hasPermission(PermissionCode.OpsReinspectionCreate) ? summary.pendingReinspections : 0);
      metrics.push({
        id: 'operationsCenter',
        label: '运维中心',
        value: visibleTaskCount > 0 ? `${visibleTaskCount}` : '可用',
        status: visibleTaskCount > 0 ? '待处理任务' : '授权功能',
        tone: AppColors.Primary
      });
    }

    if (WorkbenchService.canAccessManagementCenter()) {
      metrics.push({
        id: 'managementCenter',
        label: '管理中心',
        value: WorkbenchService.canReviewDeviceChange() ? `${summary.pendingChangeRequests}` : '可用',
        status: WorkbenchService.canReviewDeviceChange() ? '待审核事项' : '操作审计',
        tone: AppColors.Primary
      });
    }

    return metrics;
  }

  static getActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [];

    if (WorkbenchService.canAccessArchiveCenter()) {
      actions.push({
        id: WorkbenchActionId.ArchiveCenter,
        title: '档案中心',
        tone: AppColors.Primary
      });
    }

    if (WorkbenchService.canAccessOperationsCenter()) {
      actions.push({
        id: WorkbenchActionId.OperationsCenter,
        title: '运维中心',
        tone: AppColors.Primary
      });
    }

    if (WorkbenchService.canAccessManagementCenter()) {
      actions.push({
        id: WorkbenchActionId.ManagementCenter,
        title: '管理中心',
        tone: AppColors.Primary
      });
    }

    return actions;
  }

  static getArchiveCenterActions(): WorkbenchAction[] {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveDeviceRead)) {
      return [];
    }

    const actions: WorkbenchAction[] = [{
      id: WorkbenchActionId.DeviceQuery,
      title: '查询设备档案',
      tone: AppColors.Primary
    }];

    if (SessionStore.hasPermission(PermissionCode.ArchiveDeviceCreate)) {
      actions.push({
        id: WorkbenchActionId.DeviceArchiveCreate,
        title: '添加设备档案',
        tone: AppColors.Primary
      });
    }

    return actions;
  }

  static getOperationsCenterActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [];

    if (SessionStore.hasPermission(PermissionCode.OpsDeviceVerify)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.DeviceVerification, '核验与报修', AppColors.Primary));
    }

    if (SessionStore.hasPermission(PermissionCode.OpsRepairTaskAccept)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.AvailableRepairTask, '任务接取', AppColors.Primary));
    }

    if (SessionStore.hasPermission(PermissionCode.OpsRepairReportCreate)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.MyRepairTask, '维修任务', AppColors.Primary));
    }

    if (SessionStore.hasPermission(PermissionCode.OpsReinspectionCreate)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.ReinspectionTask, '复检任务', AppColors.Primary));
    }

    actions.push(WorkbenchService.createAction(WorkbenchActionId.OperationsRecord, '历史记录', AppColors.Primary));

    return actions;
  }

  static getManagementCenterActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [];
    if (WorkbenchService.canReviewDeviceChange()) {
      actions.push({
        id: WorkbenchActionId.DeviceChangeReview,
        title: '档案审核',
        tone: AppColors.Primary
      });
    }

    if (SessionStore.hasPermission(PermissionCode.MgmtAuditLogRead)) {
      actions.push({
        id: WorkbenchActionId.OperationRecord,
        title: '记录中心',
        tone: AppColors.Primary
      });
    }

    return actions;
  }

  static getStatusItems(): WorkbenchStatusItem[] {
    const items: WorkbenchStatusItem[] = [
      {
        id: 'network',
        name: '后端服务',
        value: ApiClient.getRuntimeStatusLabel(),
        tone: ApiClient.getRuntimeStatusTone()
      },
      {
        id: 'auth',
        name: '认证状态',
        value: SessionStore.isAuthenticated() ? '已登录' : '未登录',
        tone: SessionStore.isAuthenticated() ? AppColors.Success : AppColors.Danger
      }
    ];

    return items;
  }

  static getPendingChangeCount(): number {
    return WorkbenchService.getSummary().pendingChangeRequests;
  }

  static getPendingFaultCount(): number {
    return WorkbenchService.getSummary().availableRepairTasks;
  }

  static getActiveRepairTaskCount(): number {
    return WorkbenchService.getSummary().activeRepairTasks;
  }

  static getPendingReinspectionCount(): number {
    return WorkbenchService.getSummary().pendingReinspections;
  }

  static async refreshSummaryRemoteFirst(): Promise<ApiResponse<WorkbenchSummary>> {
    if (!ApiClient.isConfigured()) {
      const emptySummary = WorkbenchService.createEmptySummary();
      WorkbenchService.updateCachedSummary(emptySummary);
      return ApiClient.createServiceUnavailableResponse<WorkbenchSummary>();
    }

    const response = await ApiClient.request<WorkbenchSummary>('/api/v1/workbench/summary', 'GET', true);
    if (response.success && response.data !== undefined) {
      WorkbenchService.updateCachedSummary(WorkbenchService.normalizeSummary(response.data));
    }

    return response;
  }

  static clearCachedSummary(): void {
    WorkbenchService.cachedSummary = undefined;
    WorkbenchRefreshStore.notifyChanged();
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

  static canReviewDeviceChange(): boolean {
    return SessionStore.hasPermission(PermissionCode.MgmtArchiveChangeReview);
  }

  private static createAction(id: WorkbenchActionId, title: string, tone: string): WorkbenchAction {
    return {
      id,
      title,
      tone
    };
  }

  private static getSummary(): WorkbenchSummary {
    return WorkbenchService.cachedSummary === undefined ?
      WorkbenchService.createEmptySummary() : WorkbenchService.cachedSummary;
  }

  private static createEmptySummary(): WorkbenchSummary {
    return {
      pendingChangeRequests: 0,
      availableRepairTasks: 0,
      activeRepairTasks: 0,
      pendingReinspections: 0
    };
  }

  private static normalizeSummary(summary: WorkbenchSummary): WorkbenchSummary {
    return {
      pendingChangeRequests: WorkbenchService.normalizeCount(summary.pendingChangeRequests),
      availableRepairTasks: WorkbenchService.normalizeCount(summary.availableRepairTasks),
      activeRepairTasks: WorkbenchService.normalizeCount(summary.activeRepairTasks),
      pendingReinspections: WorkbenchService.normalizeCount(summary.pendingReinspections)
    };
  }

  private static normalizeCount(value: number): number {
    if (value !== value || value < 0) {
      return 0;
    }

    return Math.floor(value);
  }

  private static updateCachedSummary(summary: WorkbenchSummary): void {
    WorkbenchService.cachedSummary = summary;
    WorkbenchRefreshStore.notifyChanged();
  }
}
