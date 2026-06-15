import { AppColors } from '../../styles/AppTheme';
import { ApiResponse } from '../../models/common/ApiModels';
import { FaultSeverity, FaultType } from '../../models/operations/FaultModels';
import {
  TaskAcceptanceListResult,
  TaskAcceptanceQuery,
  TaskAcceptanceItem,
  RepairTaskListResult,
  RepairTaskItem,
  RepairerWorkloadSnapshot,
  RepairerWorkloadStatus,
  RepairReportForm,
  RepairReportRecord,
  RepairReportResult,
  RepairTaskAcceptResult,
  RepairTaskStatus,
  RepairTaskValidationResult
} from '../../models/operations/RepairTaskModels';
import { ApiClient } from '../common/ApiClient';

const DEFAULT_RADIUS_KM = 10;
const MIN_RADIUS_KM = 1;
const IDLE_MAX_RADIUS_KM = 30;
const LOW_LOAD_MAX_RADIUS_KM = 20;
const MEDIUM_LOAD_MAX_RADIUS_KM = 10;
const MAX_RADIUS_KM = IDLE_MAX_RADIUS_KM;
const MAX_ACTIVE_REPAIR_TASK_COUNT = 3;
const MAX_REPAIR_PROCESS_LENGTH = 1000;

interface DeviceLocationApiResult {
  address: string;
  longitude?: number;
  latitude?: number;
}

interface TaskAcceptanceApiItem {
  id: string;
  faultReportId: string;
  faultReportNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: FaultType;
  severity: FaultSeverity;
  distanceKm?: number;
  location: DeviceLocationApiResult;
  submittedAt: string;
  status: RepairTaskStatus;
  taskType?: string;
}

interface RepairTaskApiItem {
  id: string;
  repairTaskNo: string;
  faultReportNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: FaultType;
  severity: FaultSeverity;
  acceptedAt: string;
  status: RepairTaskStatus;
}

interface RepairTaskAcceptApiResult {
  repairTaskId: string;
  status: RepairTaskStatus;
  acceptedAt: string;
}

interface RepairTaskAcceptRequestBody {
  longitude?: number;
  latitude?: number;
}

interface RepairReportApiResult {
  id: string;
  repairReportNo: string;
  repairTaskId: string;
  result: RepairReportResult;
  createdAt: string;
}

interface TaskAcceptanceApiListResult {
  radiusKm: number;
  workload?: RepairerWorkloadSnapshot;
  items: TaskAcceptanceApiItem[];
  total: number;
}

interface ApiListResult<T> {
  items: T[];
  total: number;
}

export class RepairTaskService {
  static getDefaultRadiusKm(): number {
    return DEFAULT_RADIUS_KM;
  }

  static getMaxRadiusKm(): number {
    return MAX_RADIUS_KM;
  }

  static getLowLoadMaxRadiusKm(): number {
    return LOW_LOAD_MAX_RADIUS_KM;
  }

  static getMediumLoadMaxRadiusKm(): number {
    return MEDIUM_LOAD_MAX_RADIUS_KM;
  }

  static getMaxActiveRepairTaskCount(): number {
    return MAX_ACTIVE_REPAIR_TASK_COUNT;
  }

  static normalizeRadiusKm(radiusKm: number): number {
    return Math.round(radiusKm);
  }

  static createWorkloadSnapshot(activeTaskCount: number): RepairerWorkloadSnapshot {
    const normalizedActiveTaskCount = Math.max(0, Math.round(activeTaskCount));
    if (normalizedActiveTaskCount >= MAX_ACTIVE_REPAIR_TASK_COUNT) {
      return {
        status: RepairerWorkloadStatus.Busy,
        activeTaskCount: normalizedActiveTaskCount,
        maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
        maxRadiusKm: 0,
        recommendedRadiusKm: 0,
        message: '当前进行中的维修任务已达到上限，暂不可继续接取。请完成并提交维修报告后再刷新任务。',
        canAccept: false
      };
    }

    if (normalizedActiveTaskCount >= 2) {
      return {
        status: RepairerWorkloadStatus.MediumLoad,
        activeTaskCount: normalizedActiveTaskCount,
        maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
        maxRadiusKm: MEDIUM_LOAD_MAX_RADIUS_KM,
        recommendedRadiusKm: MEDIUM_LOAD_MAX_RADIUS_KM,
        message: '当前进行中的维修任务较多，系统已限制可接取范围。请优先处理已接取任务。',
        canAccept: true
      };
    }

    if (normalizedActiveTaskCount > 0) {
      return {
        status: RepairerWorkloadStatus.LowLoad,
        activeTaskCount: normalizedActiveTaskCount,
        maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
        maxRadiusKm: LOW_LOAD_MAX_RADIUS_KM,
        recommendedRadiusKm: LOW_LOAD_MAX_RADIUS_KM,
        message: '当前已有进行中的维修任务，系统已限制可接取范围。请优先处理已接取任务。',
        canAccept: true
      };
    }

    return {
      status: RepairerWorkloadStatus.Idle,
      activeTaskCount: normalizedActiveTaskCount,
      maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
      maxRadiusKm: IDLE_MAX_RADIUS_KM,
      recommendedRadiusKm: DEFAULT_RADIUS_KM,
      message: '当前无进行中的维修任务，可接取服务范围内的故障任务。',
      canAccept: true
    };
  }

  static getCurrentWorkloadSnapshot(): RepairerWorkloadSnapshot {
    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createUnavailableWorkloadSnapshot();
    }

    return RepairTaskService.createWorkloadSnapshot(0);
  }

  static async getCurrentWorkloadSnapshotRemoteFirst(): Promise<ApiResponse<RepairerWorkloadSnapshot>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RepairerWorkloadSnapshot>();
    }

    const response = await RepairTaskService.queryRepairTasksRemoteFirst();
    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    const tasks = response.data === undefined ? [] : response.data.items;
    return {
      success: true,
      data: RepairTaskService.createWorkloadSnapshot(RepairTaskService.countActiveRepairTasks(tasks)),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static validateTaskAcceptanceQuery(
    query: TaskAcceptanceQuery,
    workloadSnapshot?: RepairerWorkloadSnapshot
  ): RepairTaskValidationResult {
    const radiusKm = RepairTaskService.normalizeRadiusKm(query.radiusKm);
    if (radiusKm !== radiusKm || radiusKm < MIN_RADIUS_KM || radiusKm > MAX_RADIUS_KM) {
      return {
        valid: false,
        message: '查询范围必须在1到30公里之间'
      };
    }

    if ((query.longitude === undefined) !== (query.latitude === undefined)) {
      return {
        valid: false,
        message: '经纬度必须同时提供'
      };
    }

    if (query.longitude !== undefined &&
      (query.longitude < -180 || query.longitude > 180 ||
        query.latitude === undefined || query.latitude < -90 || query.latitude > 90)) {
      return {
        valid: false,
        message: '经纬度超出有效范围'
      };
    }

    const workload = workloadSnapshot === undefined ? RepairTaskService.getCurrentWorkloadSnapshot() : workloadSnapshot;
    const workloadValidation = RepairTaskService.validateRepairerCanAccept(workload);
    if (!workloadValidation.valid) {
      return workloadValidation;
    }

    if (radiusKm > workload.maxRadiusKm) {
      return {
        valid: false,
        message: `当前处于${RepairTaskService.formatWorkloadStatus(workload.status)}状态，查询范围不能超过${workload.maxRadiusKm}公里。`
      };
    }

    return {
      valid: true,
      message: '',
      normalizedRadiusKm: radiusKm
    };
  }

  static async queryTaskAcceptanceRemoteFirst(
    query: TaskAcceptanceQuery,
    workloadSnapshot?: RepairerWorkloadSnapshot
  ): Promise<ApiResponse<TaskAcceptanceListResult>> {
    let workload = workloadSnapshot;
    if (workload === undefined) {
      const workloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
      if (!workloadResponse.success || workloadResponse.data === undefined) {
        return {
          success: false,
          error: workloadResponse.error,
          requestId: workloadResponse.requestId,
          timestamp: workloadResponse.timestamp
        };
      }

      workload = workloadResponse.data;
    }

    const validation = RepairTaskService.validateTaskAcceptanceQuery(query, workload);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'TASK_ACCEPTANCE_QUERY_INVALID',
          message: validation.message
        }
      };
    }

    const radiusKm = validation.normalizedRadiusKm ?
      validation.normalizedRadiusKm : RepairTaskService.normalizeRadiusKm(query.radiusKm);
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<TaskAcceptanceListResult>();
    }

    const locationQuery = query.longitude !== undefined && query.latitude !== undefined ?
      `&longitude=${query.longitude}&latitude=${query.latitude}` : '';
    const response = await ApiClient.request<TaskAcceptanceApiListResult>(
      `/api/v1/operation-tasks/available?radiusKm=${radiusKm}${locationQuery}`,
      'GET',
      true
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        radiusKm: response.data === undefined ? radiusKm : response.data.radiusKm,
        items: response.data === undefined ? [] : response.data.items.map((item: TaskAcceptanceApiItem): TaskAcceptanceItem => {
          return RepairTaskService.mapTaskAcceptanceItem(item);
        }),
        total: response.data === undefined ? 0 : response.data.total,
        workload: response.data === undefined || response.data.workload === undefined ? workload : response.data.workload
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static async acceptRepairTaskRemoteFirst(
    taskId: string,
    longitude?: number,
    latitude?: number
  ): Promise<ApiResponse<RepairTaskAcceptResult>> {
    const validation = RepairTaskService.validateRepairTaskId(taskId);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'REPAIR_TASK_ACCEPT_INVALID',
          message: validation.message
        }
      };
    }

    const workloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
    if (!workloadResponse.success || workloadResponse.data === undefined) {
      return {
        success: false,
        error: workloadResponse.error,
        requestId: workloadResponse.requestId,
        timestamp: workloadResponse.timestamp
      };
    }

    const workloadValidation = RepairTaskService.validateRepairerCanAccept(workloadResponse.data);
    if (!workloadValidation.valid) {
      return {
        success: false,
        error: {
          code: 'REPAIRER_WORKLOAD_BLOCKED',
          message: workloadValidation.message
        },
        requestId: workloadResponse.requestId,
        timestamp: workloadResponse.timestamp
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RepairTaskAcceptResult>();
    }

    const requestBody: RepairTaskAcceptRequestBody = {};
    if (longitude !== undefined && latitude !== undefined) {
      requestBody.longitude = longitude;
      requestBody.latitude = latitude;
    }

    const faultReportId = encodeURIComponent(taskId.trim());
    const response = await ApiClient.request<RepairTaskAcceptApiResult>(
      `/api/v1/fault-reports/${faultReportId}/accept`,
      'POST',
      true,
      JSON.stringify(requestBody)
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'REPAIR_TASK_ACCEPT_RESPONSE_INVALID',
          message: '维修任务接取响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        taskId: response.data.repairTaskId,
        status: response.data.status,
        acceptedAt: response.data.acceptedAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static async queryRepairTasksRemoteFirst(): Promise<ApiResponse<RepairTaskListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RepairTaskListResult>();
    }

    const response = await ApiClient.request<ApiListResult<RepairTaskApiItem>>('/api/v1/repair-tasks/accepted', 'GET', true);

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        items: response.data === undefined ? [] : response.data.items.map((item: RepairTaskApiItem): RepairTaskItem => {
          return RepairTaskService.mapRepairTaskItem(item);
        }),
        total: response.data === undefined ? 0 : response.data.total
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static validateRepairReportForm(form: RepairReportForm): RepairTaskValidationResult {
    const taskId = form.taskId.trim();
    if (taskId.length === 0) {
      return {
        valid: false,
        message: '请输入维修任务编号'
      };
    }

    if (taskId.length > 64) {
      return {
        valid: false,
        message: '维修任务编号不能超过64字'
      };
    }

    if (!RepairTaskService.isKnownRepairReportResult(form.result)) {
      return {
        valid: false,
        message: '请选择维修结果'
      };
    }

    const repairedAt = form.repairedAt.trim();
    if (repairedAt.length === 0) {
      return {
        valid: false,
        message: '请选择维修时间'
      };
    }

    if (repairedAt.length > 64) {
      return {
        valid: false,
        message: '维修时间不能超过64字'
      };
    }

    const processDescription = form.processDescription.trim();
    if (processDescription.length === 0) {
      return {
        valid: false,
        message: '请输入维修说明'
      };
    }

    if (processDescription.length > MAX_REPAIR_PROCESS_LENGTH) {
      return {
        valid: false,
        message: '维修说明不能超过1000字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static async submitRepairReportRemoteFirst(form: RepairReportForm): Promise<ApiResponse<RepairReportRecord>> {
    const validation = RepairTaskService.validateRepairReportForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'REPAIR_REPORT_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RepairReportRecord>();
    }

    const taskId = encodeURIComponent(form.taskId.trim());
    const response = await ApiClient.request<RepairReportApiResult>(
      `/api/v1/repair-tasks/${taskId}/repair-reports`,
      'POST',
      true,
      JSON.stringify({
        result: form.result,
        repairedAt: form.repairedAt.trim(),
        processDescription: form.processDescription.trim(),
        partsUsed: form.partsUsed.trim()
      })
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'REPAIR_REPORT_RESPONSE_INVALID',
          message: '维修报告响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        id: response.data.id,
        reportNo: response.data.repairReportNo,
        taskId: response.data.repairTaskId,
        result: response.data.result,
        submittedAt: response.data.createdAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static validateRepairTaskId(taskId: string): RepairTaskValidationResult {
    if (taskId.trim().length === 0) {
      return {
        valid: false,
        message: '请选择需要接取的维修任务'
      };
    }

    if (taskId.trim().length > 64) {
      return {
        valid: false,
        message: '维修任务标识不能超过64字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static validateRepairerCanAccept(workload: RepairerWorkloadSnapshot): RepairTaskValidationResult {
    if (!workload.canAccept || workload.status === RepairerWorkloadStatus.Busy) {
      return {
        valid: false,
        message: workload.message
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static formatWorkloadStatus(status: RepairerWorkloadStatus): string {
    switch (status) {
      case RepairerWorkloadStatus.Idle:
        return '空闲';
      case RepairerWorkloadStatus.LowLoad:
        return '低负载';
      case RepairerWorkloadStatus.MediumLoad:
        return '中负载';
      case RepairerWorkloadStatus.Busy:
        return '忙碌';
      case RepairerWorkloadStatus.Unavailable:
        return '未配置';
      default:
        return '-';
    }
  }

  static getWorkloadStatusTone(status: RepairerWorkloadStatus): string {
    switch (status) {
      case RepairerWorkloadStatus.Idle:
        return AppColors.Success;
      case RepairerWorkloadStatus.LowLoad:
        return AppColors.Primary;
      case RepairerWorkloadStatus.MediumLoad:
        return AppColors.Warning;
      case RepairerWorkloadStatus.Busy:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  private static createUnavailableWorkloadSnapshot(): RepairerWorkloadSnapshot {
    return {
      status: RepairerWorkloadStatus.Unavailable,
      activeTaskCount: 0,
      maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
      maxRadiusKm: 0,
      recommendedRadiusKm: 0,
      message: '后端服务地址未配置，请先配置后再刷新维修任务。',
      canAccept: false
    };
  }

  static formatTaskStatus(status: RepairTaskStatus): string {
    switch (status) {
      case RepairTaskStatus.Available:
        return '待接取';
      case RepairTaskStatus.Accepted:
        return '已接取';
      case RepairTaskStatus.Processing:
        return '维修中';
      case RepairTaskStatus.ReportSubmitted:
        return '报告已提交';
      default:
        return '-';
    }
  }

  static formatRepairReportResult(result: RepairReportResult): string {
    switch (result) {
      case RepairReportResult.Repaired:
        return '已修复';
      case RepairReportResult.TemporaryRestored:
        return '临时修复';
      case RepairReportResult.Unresolved:
        return '未修复';
      default:
        return '-';
    }
  }

  private static isKnownRepairReportResult(result: RepairReportResult): boolean {
    return result === RepairReportResult.Repaired ||
      result === RepairReportResult.TemporaryRestored ||
      result === RepairReportResult.Unresolved;
  }

  private static countActiveRepairTasks(tasks: RepairTaskItem[]): number {
    return tasks.filter((task: RepairTaskItem) => {
      return task.status === RepairTaskStatus.Accepted || task.status === RepairTaskStatus.Processing;
    }).length;
  }

  private static mapTaskAcceptanceItem(item: TaskAcceptanceApiItem): TaskAcceptanceItem {
    return {
      id: item.faultReportId,
      faultNo: item.faultReportNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      faultType: item.faultType,
      severity: item.severity,
      distanceKm: typeof item.distanceKm === 'number' ? item.distanceKm : undefined,
      location: item.location.address,
      submittedAt: item.submittedAt,
      status: item.status,
      taskType: item.taskType !== undefined && item.taskType.length > 0 ? item.taskType : 'REPAIR'
    };
  }

  private static mapRepairTaskItem(item: RepairTaskApiItem): RepairTaskItem {
    return {
      id: item.id,
      taskNo: item.repairTaskNo,
      faultNo: item.faultReportNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      faultType: item.faultType,
      severity: item.severity,
      acceptedAt: item.acceptedAt,
      status: item.status
    };
  }
}
