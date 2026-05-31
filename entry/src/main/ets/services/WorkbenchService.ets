import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/WorkbenchModels';
import {
  ArchiveCenterPermissions,
  ManagementCenterPermissions,
  OperationsCenterPermissions,
  PermissionCode
} from '../models/PermissionModels';
import { ApiClient } from './ApiClient';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalRepairTaskRepository } from './LocalRepairTaskRepository';
import { LocalReinspectionRepository } from './LocalReinspectionRepository';
import { SessionStore } from '../stores/SessionStore';

export class WorkbenchService {
  static getMetrics(): WorkbenchMetric[] {
    const pendingChangeCount = WorkbenchService.getPendingChangeCount();
    const pendingFaultCount = WorkbenchService.getPendingFaultCount();
    const pendingReinspectionCount = WorkbenchService.getPendingReinspectionCount();
    const metrics: WorkbenchMetric[] = [];

    if (WorkbenchService.canAccessArchiveCenter()) {
      metrics.push({
        id: 'archiveCenter',
        label: '档案中心',
        value: WorkbenchService.canReviewDeviceChange() ? `${pendingChangeCount}` : '可用',
        status: WorkbenchService.canReviewDeviceChange() ? '待审核变更' : '档案查询',
        tone: '#2F6FED'
      });
    }

    if (WorkbenchService.canAccessOperationsCenter()) {
      const visibleTaskCount =
        (SessionStore.hasPermission(PermissionCode.RepairTaskAccept) ? pendingFaultCount : 0) +
        (SessionStore.hasPermission(PermissionCode.ReinspectionCreate) ? pendingReinspectionCount : 0);
      metrics.push({
        id: 'operationsCenter',
        label: '运维中心',
        value: visibleTaskCount > 0 ? `${visibleTaskCount}` : '可用',
        status: visibleTaskCount > 0 ? '待处理任务' : '授权功能',
        tone: '#D9480F'
      });
    }

    if (WorkbenchService.canAccessManagementCenter()) {
      metrics.push({
        id: 'managementCenter',
        label: '管理中心',
        value: WorkbenchService.canReviewDeviceChange() ? `${pendingChangeCount}` : '可用',
        status: WorkbenchService.canReviewDeviceChange() ? '待审核事项' : '操作审计',
        tone: '#845EF7'
      });
    }

    metrics.push({
      id: 'offlineDrafts',
      label: '待同步草稿',
      value: '0',
      status: '离线数据',
      tone: '#087F5B'
    });

    return metrics;
  }

  static getActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [];

    if (WorkbenchService.canAccessArchiveCenter()) {
      actions.push({
        id: WorkbenchActionId.ArchiveCenter,
        title: '档案中心',
        summary: '查询档案与发起档案变更',
        tone: '#2F6FED'
      });
    }

    if (WorkbenchService.canAccessOperationsCenter()) {
      actions.push({
        id: WorkbenchActionId.OperationsCenter,
        title: '运维中心',
        summary: '核验、报修、维修与复检',
        tone: '#D9480F'
      });
    }

    if (WorkbenchService.canAccessManagementCenter()) {
      actions.push({
        id: WorkbenchActionId.ManagementCenter,
        title: '管理中心',
        summary: '审核变更与查看操作记录',
        tone: '#495057'
      });
    }

    return actions;
  }

  static getArchiveCenterActions(): WorkbenchAction[] {
    if (!SessionStore.hasPermission(PermissionCode.DeviceRead)) {
      return [];
    }

    return [{
      id: WorkbenchActionId.DeviceQuery,
      title: '设备档案查询',
      summary: '按编号或二维码定位档案',
      tone: '#2F6FED'
    }];
  }

  static getOperationsCenterActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [];

    if (SessionStore.hasPermission(PermissionCode.DeviceVerify)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.DeviceVerification, '状态核验',
        '提交现场核验记录', '#0B7285'));
    }

    if (SessionStore.hasPermission(PermissionCode.FaultReportCreate)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.FaultReport, '故障报告',
        '登记设备故障信息', '#D9480F'));
    }

    if (SessionStore.hasPermission(PermissionCode.RepairTaskAccept)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.AvailableRepairTask, '附近故障',
        '查看可接取任务', '#5C7CFA'));
    }

    if (SessionStore.hasPermission(PermissionCode.RepairReportCreate)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.MyRepairTask, '我的维修',
        '处理已接取任务', '#E67700'));
    }

    if (SessionStore.hasPermission(PermissionCode.ReinspectionCreate)) {
      actions.push(WorkbenchService.createAction(WorkbenchActionId.ReinspectionTask, '复检任务',
        '确认高等级故障结果', '#845EF7'));
    }

    return actions;
  }

  static getManagementCenterActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [];
    if (WorkbenchService.canReviewDeviceChange()) {
      actions.push({
        id: WorkbenchActionId.DeviceChangeReview,
        title: '变更审核',
        summary: '审核待处理档案变更',
        tone: '#2B8A3E'
      });
    }

    if (SessionStore.hasPermission(PermissionCode.AuditLogRead)) {
      actions.push({
        id: WorkbenchActionId.OperationRecord,
        title: '操作记录',
        summary: '查看业务流转记录',
        tone: '#495057'
      });
    }

    return actions;
  }

  static getStatusItems(): WorkbenchStatusItem[] {
    return [
      {
        id: 'network',
        name: '网络状态',
        value: ApiClient.getRuntimeStatusLabel(),
        tone: ApiClient.getRuntimeStatusTone()
      },
      {
        id: 'auth',
        name: '认证状态',
        value: SessionStore.isAuthenticated() ? '已登录' : '未登录',
        tone: SessionStore.isAuthenticated() ? '#087F5B' : '#D9480F'
      },
      {
        id: 'sync',
        name: '同步状态',
        value: '无待同步',
        tone: '#087F5B'
      }
    ];
  }

  static getPendingChangeCount(): number {
    return ApiClient.isConfigured() ? 0 : LocalDeviceArchiveRepository.getPendingChangeCount();
  }

  static getPendingFaultCount(): number {
    return ApiClient.isConfigured() ? 0 : LocalRepairTaskRepository.getPendingAvailableTaskCount();
  }

  static getPendingReinspectionCount(): number {
    return ApiClient.isConfigured() ? 0 : LocalReinspectionRepository.getPendingTaskCount();
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
    return SessionStore.hasPermission(PermissionCode.DeviceChangeReview);
  }

  private static createAction(id: WorkbenchActionId, title: string, summary: string, tone: string): WorkbenchAction {
    return {
      id,
      title,
      summary,
      tone
    };
  }
}
