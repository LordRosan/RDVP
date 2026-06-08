import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import { FaultSeverity, FaultType } from '../models/FaultModels';
import {
  AvailableRepairTaskListResult,
  AvailableRepairTaskQuery,
  AvailableRepairTaskSummary,
  MyRepairTaskListResult,
  MyRepairTaskSummary,
  RepairerWorkloadSnapshot,
  RepairerWorkloadStatus,
  RepairReportForm,
  RepairReportRecord,
  RepairReportResult,
  RepairTaskAcceptResult,
  RepairTaskStatus,
  RepairTaskValidationResult
} from '../models/RepairTaskModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { LocalRepairTaskRepository } from './LocalRepairTaskRepository';
import { SessionStore } from '../stores/SessionStore';

const DEFAULT_RADIUS_KM = 10;
const MIN_RADIUS_KM = 1;
const IDLE_MAX_RADIUS_KM = 20;
const LOW_LOAD_MAX_RADIUS_KM = 10;
const MAX_RADIUS_KM = IDLE_MAX_RADIUS_KM;
const MAX_ACTIVE_REPAIR_TASK_COUNT = 2;
const MAX_REPAIR_PROCESS_LENGTH = 1000;
const MAX_PARTS_USED_LENGTH = 500;

interface DeviceLocationApiResult {
  address: string;
  longitude?: number;
  latitude?: number;
}

interface AvailableRepairTaskApiSummary {
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
}

interface MyRepairTaskApiSummary {
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

interface AvailableRepairTaskApiListResult {
  radiusKm: number;
  workload?: RepairerWorkloadSnapshot;
  items: AvailableRepairTaskApiSummary[];
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
    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createWorkloadSnapshot(LocalRepairTaskRepository.getActiveMyTaskCount());
    }

    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createUnavailableWorkloadSnapshot();
    }

    return RepairTaskService.createWorkloadSnapshot(0);
  }

  static async getCurrentWorkloadSnapshotRemoteFirst(): Promise<ApiResponse<RepairerWorkloadSnapshot>> {
    if (ApiClient.isOfflineMode()) {
      return {
        success: true,
        data: RepairTaskService.createWorkloadSnapshot(LocalRepairTaskRepository.getActiveMyTaskCount()),
        requestId: 'local-repairer-workload',
        timestamp: new Date().toISOString()
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RepairerWorkloadSnapshot>();
    }

    const response = await RepairTaskService.queryMyRepairTasksRemoteFirst();
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

  static validateAvailableRepairTaskQuery(
    query: AvailableRepairTaskQuery,
    workloadSnapshot?: RepairerWorkloadSnapshot
  ): RepairTaskValidationResult {
    const radiusKm = RepairTaskService.normalizeRadiusKm(query.radiusKm);
    if (radiusKm !== radiusKm || radiusKm < MIN_RADIUS_KM || radiusKm > MAX_RADIUS_KM) {
      return {
        valid: false,
        message: '查询范围必须在1到20公里之间'
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

  static queryAvailableRepairTasks(
    query: AvailableRepairTaskQuery,
    workloadSnapshot?: RepairerWorkloadSnapshot
  ): ApiResponse<AvailableRepairTaskListResult> {
    const workload = workloadSnapshot === undefined ? RepairTaskService.getCurrentWorkloadSnapshot() : workloadSnapshot;
    const validation = RepairTaskService.validateAvailableRepairTaskQuery(query, workload);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'AVAILABLE_REPAIR_TASK_QUERY_INVALID',
          message: validation.message
        }
      };
    }

    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalAvailableTasksResponse(validation.normalizedRadiusKm ?
        validation.normalizedRadiusKm : RepairTaskService.normalizeRadiusKm(query.radiusKm), workload);
    }

    return ApiClient.createServiceUnavailableResponse<AvailableRepairTaskListResult>();
  }

  static async queryAvailableRepairTasksRemoteFirst(
    query: AvailableRepairTaskQuery,
    workloadSnapshot?: RepairerWorkloadSnapshot
  ): Promise<ApiResponse<AvailableRepairTaskListResult>> {
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

    const validation = RepairTaskService.validateAvailableRepairTaskQuery(query, workload);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'AVAILABLE_REPAIR_TASK_QUERY_INVALID',
          message: validation.message
        }
      };
    }

    const radiusKm = validation.normalizedRadiusKm ?
      validation.normalizedRadiusKm : RepairTaskService.normalizeRadiusKm(query.radiusKm);
    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalAvailableTasksResponse(radiusKm, workload);
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<AvailableRepairTaskListResult>();
    }

    const locationQuery = query.longitude !== undefined && query.latitude !== undefined ?
      `&longitude=${query.longitude}&latitude=${query.latitude}` : '';
    const response = await ApiClient.request<AvailableRepairTaskApiListResult>(
      `/api/v1/repair-tasks/available?radiusKm=${radiusKm}${locationQuery}`,
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
        items: response.data === undefined ? [] : response.data.items.map((item: AvailableRepairTaskApiSummary): AvailableRepairTaskSummary => {
          return RepairTaskService.mapAvailableTask(item);
        }),
        total: response.data === undefined ? 0 : response.data.total,
        workload: response.data === undefined || response.data.workload === undefined ? workload : response.data.workload
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static acceptRepairTask(taskId: string): ApiResponse<RepairTaskAcceptResult> {
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

    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalAcceptTaskResponse(taskId);
    }

    return ApiClient.createServiceUnavailableResponse<RepairTaskAcceptResult>();
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

    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalAcceptTaskResponse(taskId, workloadResponse.data);
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

  static queryMyRepairTasks(): ApiResponse<MyRepairTaskListResult> {
    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalMyTasksResponse();
    }

    return ApiClient.createServiceUnavailableResponse<MyRepairTaskListResult>();
  }

  static async queryMyRepairTasksRemoteFirst(): Promise<ApiResponse<MyRepairTaskListResult>> {
    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalMyTasksResponse();
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<MyRepairTaskListResult>();
    }

    const response = await ApiClient.request<ApiListResult<MyRepairTaskApiSummary>>('/api/v1/repair-tasks/my', 'GET', true);

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
        items: response.data === undefined ? [] : response.data.items.map((item: MyRepairTaskApiSummary): MyRepairTaskSummary => {
          return RepairTaskService.mapMyTask(item);
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
        message: '请输入维修完成时间'
      };
    }

    if (repairedAt.length > 64) {
      return {
        valid: false,
        message: '维修完成时间不能超过64字'
      };
    }

    const processDescription = form.processDescription.trim();
    if (processDescription.length === 0) {
      return {
        valid: false,
        message: '请输入维修过程'
      };
    }

    if (processDescription.length > MAX_REPAIR_PROCESS_LENGTH) {
      return {
        valid: false,
        message: '维修过程不能超过1000字'
      };
    }

    if (form.partsUsed.trim().length > MAX_PARTS_USED_LENGTH) {
      return {
        valid: false,
        message: '更换部件不能超过500字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static submitRepairReport(form: RepairReportForm): ApiResponse<RepairReportRecord> {
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

    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalRepairReportResponse(form);
    }

    return ApiClient.createServiceUnavailableResponse<RepairReportRecord>();
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

    if (ApiClient.isOfflineMode()) {
      return RepairTaskService.createLocalRepairReportResponse(form);
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
      case RepairerWorkloadStatus.Busy:
        return '忙碌';
      case RepairerWorkloadStatus.Offline:
        return '离线';
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
      case RepairerWorkloadStatus.Busy:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  private static createUnavailableWorkloadSnapshot(): RepairerWorkloadSnapshot {
    return {
      status: RepairerWorkloadStatus.Offline,
      activeTaskCount: 0,
      maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
      maxRadiusKm: 0,
      recommendedRadiusKm: 0,
      message: '在线模式下请先配置后端服务地址，再刷新维修任务。',
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
        return '临时恢复';
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

  private static createLocalAvailableTasksResponse(
    radiusKm: number,
    workload: RepairerWorkloadSnapshot
  ): ApiResponse<AvailableRepairTaskListResult> {
    return {
      success: true,
      data: RepairTaskService.withWorkload(LocalRepairTaskRepository.queryAvailableTasks(radiusKm), workload),
      requestId: 'local-available-repair-tasks',
      timestamp: new Date().toISOString()
    };
  }

  private static createLocalAcceptTaskResponse(
    taskId: string,
    workloadSnapshot?: RepairerWorkloadSnapshot
  ): ApiResponse<RepairTaskAcceptResult> {
    const workload = workloadSnapshot === undefined ? RepairTaskService.getCurrentWorkloadSnapshot() : workloadSnapshot;
    const workloadValidation = RepairTaskService.validateRepairerCanAccept(workload);
    if (!workloadValidation.valid) {
      return {
        success: false,
        error: {
          code: 'REPAIRER_WORKLOAD_BLOCKED',
          message: workloadValidation.message
        }
      };
    }

    const taskDistanceKm = LocalRepairTaskRepository.getAvailableTaskDistanceKm(taskId);
    if (taskDistanceKm === undefined) {
      return {
        success: false,
        error: {
          code: 'REPAIR_TASK_NOT_FOUND',
          message: '维修任务不存在或已被接取'
        }
      };
    }

    if (taskDistanceKm > workload.maxRadiusKm) {
      return {
        success: false,
        error: {
          code: 'REPAIR_TASK_OUT_OF_WORKLOAD_RANGE',
          message: `当前处于${RepairTaskService.formatWorkloadStatus(workload.status)}状态，仅可接取${workload.maxRadiusKm}公里内的维修任务。`
        }
      };
    }

    const result = LocalRepairTaskRepository.acceptTask(taskId);
    if (result === undefined) {
      return {
        success: false,
        error: {
          code: 'REPAIR_TASK_NOT_FOUND',
          message: '维修任务不存在或已被接取'
        }
      };
    }

    LocalOperationRecordRepository.append(OperationRecordType.RepairTaskAccept, '接取维修任务', result.taskId,
      '维修任务已分配给当前维修人员', SessionStore.getCurrentOperatorName());
    return {
      success: true,
      data: result,
      requestId: 'local-repair-task-accept',
      timestamp: new Date().toISOString()
    };
  }

  private static withWorkload(
    result: AvailableRepairTaskListResult,
    workload: RepairerWorkloadSnapshot
  ): AvailableRepairTaskListResult {
    return {
      radiusKm: result.radiusKm,
      items: result.items,
      total: result.total,
      workload
    };
  }

  private static countActiveRepairTasks(tasks: MyRepairTaskSummary[]): number {
    return tasks.filter((task: MyRepairTaskSummary) => {
      return task.status === RepairTaskStatus.Accepted || task.status === RepairTaskStatus.Processing;
    }).length;
  }

  private static createLocalMyTasksResponse(): ApiResponse<MyRepairTaskListResult> {
    return {
      success: true,
      data: LocalRepairTaskRepository.queryMyTasks(),
      requestId: 'local-my-repair-tasks',
      timestamp: new Date().toISOString()
    };
  }

  private static createLocalRepairReportResponse(form: RepairReportForm): ApiResponse<RepairReportRecord> {
    const record = LocalRepairTaskRepository.submitRepairReport(form);
    if (record === undefined) {
      return {
        success: false,
        error: {
          code: 'REPAIR_TASK_NOT_FOUND',
          message: '维修任务不存在或已完成'
        }
      };
    }

    LocalOperationRecordRepository.append(OperationRecordType.RepairReport, '提交维修报告', record.reportNo,
      `维修结果：${RepairTaskService.formatRepairReportResult(form.result)}`, SessionStore.getCurrentOperatorName());
    return {
      success: true,
      data: record,
      requestId: 'local-repair-report',
      timestamp: new Date().toISOString()
    };
  }

  private static mapAvailableTask(item: AvailableRepairTaskApiSummary): AvailableRepairTaskSummary {
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
      status: item.status
    };
  }

  private static mapMyTask(item: MyRepairTaskApiSummary): MyRepairTaskSummary {
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
