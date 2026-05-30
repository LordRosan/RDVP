import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/WorkbenchModels';
import { ApiClient } from './ApiClient';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalRepairTaskRepository } from './LocalRepairTaskRepository';
import { LocalReinspectionRepository } from './LocalReinspectionRepository';
import { SessionStore } from '../stores/SessionStore';

export class WorkbenchService {
  static getMetrics(): WorkbenchMetric[] {
    return [
      {
        id: 'pendingChangeRequests',
        label: '待审核变更',
        value: ApiClient.isConfigured() ? '0' : `${LocalDeviceArchiveRepository.getPendingChangeCount()}`,
        status: '设备信息',
        tone: '#2F6FED'
      },
      {
        id: 'pendingFaults',
        label: '待接取故障',
        value: ApiClient.isConfigured() ? '0' : `${LocalRepairTaskRepository.getPendingAvailableTaskCount()}`,
        status: '维修响应',
        tone: '#D9480F'
      },
      {
        id: 'pendingReinspections',
        label: '待复检',
        value: ApiClient.isConfigured() ? '0' : `${LocalReinspectionRepository.getPendingTaskCount()}`,
        status: '高等级故障',
        tone: '#845EF7'
      },
      {
        id: 'offlineDrafts',
        label: '待同步草稿',
        value: '0',
        status: '离线数据',
        tone: '#087F5B'
      }
    ];
  }

  static getActions(): WorkbenchAction[] {
    const actions: WorkbenchAction[] = [
      {
        id: WorkbenchActionId.DeviceQuery,
        title: '设备档案查询',
        summary: '按编号或二维码定位档案',
        tone: '#2F6FED'
      },
      {
        id: WorkbenchActionId.DeviceVerification,
        title: '状态核验',
        summary: '提交现场核验记录',
        tone: '#0B7285'
      },
      {
        id: WorkbenchActionId.FaultReport,
        title: '故障报告',
        summary: '登记设备故障信息',
        tone: '#D9480F'
      },
      {
        id: WorkbenchActionId.AvailableRepairTask,
        title: '附近故障',
        summary: '查看可接取任务',
        tone: '#5C7CFA'
      },
      {
        id: WorkbenchActionId.MyRepairTask,
        title: '我的维修',
        summary: '处理已接取任务',
        tone: '#E67700'
      },
      {
        id: WorkbenchActionId.ReinspectionTask,
        title: '复检任务',
        summary: '确认高等级故障结果',
        tone: '#845EF7'
      }
    ];

    if (SessionStore.hasPermission('DEVICE_CHANGE_REVIEW')) {
      actions.push({
        id: WorkbenchActionId.DeviceChangeReview,
        title: '变更审核',
        summary: '审核待处理档案变更',
        tone: '#2B8A3E'
      });
    }

    actions.push(
      {
        id: WorkbenchActionId.OperationRecord,
        title: '操作记录',
        summary: '查看业务流转记录',
        tone: '#495057'
      }
    );

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
        value: '未登录',
        tone: '#D9480F'
      },
      {
        id: 'sync',
        name: '同步状态',
        value: '无待同步',
        tone: '#087F5B'
      }
    ];
  }
}
