import { AppColors } from '../../styles/AppTheme';
import { ApiError, ApiResponse } from '../../models/common/ApiModels';
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
import { UiFeedbackService } from '../common/UiFeedbackService';

const DEFAULT_RADIUS_KM = 10;
const MIN_RADIUS_KM = 0;
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
        message: UiFeedbackService.operationUnavailable('任务接取'),
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
        message: UiFeedbackService.sanitize('当前进行中的维修任务较多，系统已限制可接取范围，请优先处理已接取任务'),
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
        message: UiFeedbackService.sanitize('当前已有进行中的维修任务，系统已限制可接取范围，请优先处理已接取任务'),
        canAccept: true
      };
    }

    return {
      status: RepairerWorkloadStatus.Idle,
      activeTaskCount: normalizedActiveTaskCount,
      maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
      maxRadiusKm: IDLE_MAX_RADIUS_KM,
      recommendedRadiusKm: DEFAULT_RADIUS_KM,
      message: UiFeedbackService.sanitize('当前无进行中的维修任务，可接取服务范围内的故障任务'),
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
        error: RepairTaskService.createTaskAcceptanceError(response.error === undefined ? '' : `${response.error.code}`),
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
        message: UiFeedbackService.incorrect('查询范围')
      };
    }

    if ((query.longitude === undefined) !== (query.latitude === undefined)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('经纬度')
      };
    }

    if (query.longitude !== undefined &&
      (query.longitude < -180 || query.longitude > 180 ||
        query.latitude === undefined || query.latitude < -90 || query.latitude > 90)) {
      return {
        valid: false,
        message: UiFeedbackService.incorrect('经纬度')
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
        message: UiFeedbackService.incorrect('查询范围')
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
    const workload = workloadSnapshot;
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

    const radiusKm = validation.normalizedRadiusKm !== undefined ?
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
    return RepairTaskService.acceptTaskRemoteFirst(taskId, 'REPAIR', longitude, latitude);
  }

  static async acceptTaskRemoteFirst(
    taskId: string,
    taskType: string,
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

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RepairTaskAcceptResult>();
    }

    const requestBody: RepairTaskAcceptRequestBody = {};
    if (longitude !== undefined && latitude !== undefined) {
      requestBody.longitude = longitude;
      requestBody.latitude = latitude;
    }

    const faultReportId = encodeURIComponent(taskId.trim());
    const endpoint = taskType === 'REINSPECTION' ?
      `/api/v1/reinspections/${faultReportId}/accept` :
      `/api/v1/fault-reports/${faultReportId}/accept`;
    const response = await ApiClient.request<RepairTaskAcceptApiResult>(
      endpoint,
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
          message: UiFeedbackService.operationUnavailable('任务接取')
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
        message: UiFeedbackService.requiredInput('维修任务编号')
      };
    }

    if (taskId.length > 64) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('维修任务编号', 64, '字')
      };
    }

    if (!RepairTaskService.isKnownRepairReportResult(form.result)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('维修结果')
      };
    }

    const repairedAt = form.repairedAt.trim();
    if (repairedAt.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('维修')
      };
    }

    if (repairedAt.length > 64) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('维修时间', 64, '字')
      };
    }

    const processDescription = form.processDescription.trim();
    if (processDescription.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('维修说明')
      };
    }

    if (processDescription.length > MAX_REPAIR_PROCESS_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('维修说明', 1000, '字')
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
          message: UiFeedbackService.operationUnavailable('提交')
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
        message: UiFeedbackService.requiredSelection('需要接取的任务')
      };
    }

    if (taskId.trim().length > 64) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('任务标识', 64, '字')
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
      message: UiFeedbackService.operationUnavailable('任务接取'),
      canAccept: false
    };
  }

  private static createTaskAcceptanceError(errorCode: string): ApiError {
    if (errorCode === 'REPAIRER_BUSY') {
      return {
        code: errorCode,
        message: UiFeedbackService.operationUnavailable('任务接取')
      };
    }

    if (errorCode === 'REPAIR_TASK_RADIUS_INVALID') {
      return {
        code: errorCode,
        message: UiFeedbackService.incorrect('可接取半径')
      };
    }

    if (errorCode === 'REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD') {
      return {
        code: errorCode,
        message: UiFeedbackService.incorrect('可接取半径')
      };
    }

    return {
      code: errorCode.length > 0 ? errorCode : 'TASK_ACCEPTANCE_UNAVAILABLE',
      message: UiFeedbackService.operationUnavailable('任务接取')
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
