import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/WorkbenchModels';

export class WorkbenchService {
  static getMetrics(): WorkbenchMetric[] {
    return [
      {
        id: 'pendingChangeRequests',
        label: '待审核变更',
        value: '0',
        status: '设备信息',
        tone: '#2F6FED'
      },
      {
        id: 'pendingFaults',
        label: '待接取故障',
        value: '0',
        status: '维修响应',
        tone: '#D9480F'
      },
      {
        id: 'pendingReinspections',
        label: '待复检',
        value: '0',
        status: '重大故障',
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
    return [
      {
        id: WorkbenchActionId.DeviceQuery,
        title: '设备查询',
        summary: '按编号或二维码定位设备',
        mark: '查',
        tone: '#2F6FED'
      },
      {
        id: WorkbenchActionId.DeviceVerification,
        title: '状态核验',
        summary: '提交现场核验记录',
        mark: '核',
        tone: '#0B7285'
      },
      {
        id: WorkbenchActionId.FaultReport,
        title: '故障报告',
        summary: '登记设备故障信息',
        mark: '报',
        tone: '#D9480F'
      },
      {
        id: WorkbenchActionId.AvailableRepairTask,
        title: '附近故障',
        summary: '查看可接取任务',
        mark: '接',
        tone: '#5C7CFA'
      },
      {
        id: WorkbenchActionId.MyRepairTask,
        title: '我的维修',
        summary: '处理已接取任务',
        mark: '修',
        tone: '#E67700'
      },
      {
        id: WorkbenchActionId.ReinspectionTask,
        title: '复检任务',
        summary: '确认重大故障结果',
        mark: '复',
        tone: '#845EF7'
      },
      {
        id: WorkbenchActionId.OperationRecord,
        title: '操作记录',
        summary: '查看业务流转记录',
        mark: '记',
        tone: '#495057'
      }
    ];
  }

  static getStatusItems(): WorkbenchStatusItem[] {
    return [
      {
        id: 'network',
        name: '网络状态',
        value: '待检测',
        tone: '#495057'
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
