import { ApiResponse } from '../models/ApiModels';
import { FaultSeverity, FaultType } from '../models/FaultModels';
import {
  AvailableRepairTaskListResult,
  AvailableRepairTaskQuery,
  AvailableRepairTaskSummary,
  MyRepairTaskListResult,
  MyRepairTaskSummary,
  RepairerAvailability,
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

const DEFAULT_RADIUS_KM = 10;
const MIN_RADIUS_KM = 1;
const MAX_RADIUS_KM = 100;
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
  faultType: string;
  severity: string;
  distanceKm: number;
  location: DeviceLocationApiResult;
  submittedAt: string;
  status: string;
}

interface MyRepairTaskApiSummary {
  id: string;
  repairTaskNo: string;
  faultReportNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: string;
  severity: string;
  acceptedAt: string;
  status: string;
}

interface RepairTaskAcceptApiResult {
  repairTaskId: string;
  status: string;
  acceptedAt: string;
}

interface RepairReportApiResult {
  id: string;
  repairReportNo: string;
  repairTaskId: string;
  result: string;
  createdAt: string;
}

interface ApiListResult<T> {
  items: T[];
  total: number;
}

export class RepairTaskService {
  static getDefaultRadiusKm(): number {
    return DEFAULT_RADIUS_KM;
  }

  static normalizeRadiusKm(radiusKm: number): number {
    return Math.round(radiusKm);
  }

  static validateAvailableRepairTaskQuery(query: AvailableRepairTaskQuery): RepairTaskValidationResult {
    const radiusKm = RepairTaskService.normalizeRadiusKm(query.radiusKm);
    if (radiusKm !== radiusKm || radiusKm < MIN_RADIUS_KM || radiusKm > MAX_RADIUS_KM) {
      return {
        valid: false,
        message: '查询范围必须在1到100公里之间'
      };
    }

    if (!RepairTaskService.isKnownAvailability(query.availability)) {
      return {
        valid: false,
        message: '维修状态无效'
      };
    }

    if (query.availability !== RepairerAvailability.Idle) {
      return {
        valid: false,
        message: '仅空闲状态可刷新附近故障'
      };
    }

    return {
      valid: true,
      message: '',
      normalizedRadiusKm: radiusKm
    };
  }

  static queryAvailableRepairTasks(query: AvailableRepairTaskQuery): ApiResponse<AvailableRepairTaskListResult> {
    const validation = RepairTaskService.validateAvailableRepairTaskQuery(query);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'AVAILABLE_REPAIR_TASK_QUERY_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createLocalAvailableTasksResponse(validation.normalizedRadiusKm ?
        validation.normalizedRadiusKm : RepairTaskService.normalizeRadiusKm(query.radiusKm));
    }

    return ApiClient.createServiceUnavailableResponse<AvailableRepairTaskListResult>();
  }

  static async queryAvailableRepairTasksRemoteFirst(
    query: AvailableRepairTaskQuery
  ): Promise<ApiResponse<AvailableRepairTaskListResult>> {
    const validation = RepairTaskService.validateAvailableRepairTaskQuery(query);
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
    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createLocalAvailableTasksResponse(radiusKm);
    }

    const response = await ApiClient.request<ApiListResult<AvailableRepairTaskApiSummary>>(
      `/api/v1/repair-tasks/available?radiusKm=${radiusKm}`,
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
        radiusKm,
        items: response.data === undefined ? [] : response.data.items.map((item: AvailableRepairTaskApiSummary): AvailableRepairTaskSummary => {
          return RepairTaskService.mapAvailableTask(item);
        }),
        total: response.data === undefined ? 0 : response.data.total
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

    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createLocalAcceptTaskResponse(taskId);
    }

    return ApiClient.createServiceUnavailableResponse<RepairTaskAcceptResult>();
  }

  static async acceptRepairTaskRemoteFirst(taskId: string): Promise<ApiResponse<RepairTaskAcceptResult>> {
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
      return RepairTaskService.createLocalAcceptTaskResponse(taskId);
    }

    const faultReportId = encodeURIComponent(taskId.trim());
    const response = await ApiClient.request<RepairTaskAcceptApiResult>(
      `/api/v1/fault-reports/${faultReportId}/accept`,
      'POST',
      true,
      JSON.stringify({})
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
        status: response.data.status as RepairTaskStatus,
        acceptedAt: response.data.acceptedAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static queryMyRepairTasks(): ApiResponse<MyRepairTaskListResult> {
    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createLocalMyTasksResponse();
    }

    return ApiClient.createServiceUnavailableResponse<MyRepairTaskListResult>();
  }

  static async queryMyRepairTasksRemoteFirst(): Promise<ApiResponse<MyRepairTaskListResult>> {
    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createLocalMyTasksResponse();
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

    if (!ApiClient.isConfigured()) {
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

    if (!ApiClient.isConfigured()) {
      return RepairTaskService.createLocalRepairReportResponse(form);
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
        result: response.data.result as RepairReportResult,
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

  static formatAvailability(availability: RepairerAvailability): string {
    switch (availability) {
      case RepairerAvailability.Idle:
        return '空闲';
      case RepairerAvailability.Busy:
        return '忙碌';
      case RepairerAvailability.Offline:
        return '离线';
      default:
        return '-';
    }
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

  private static isKnownAvailability(availability: RepairerAvailability): boolean {
    return availability === RepairerAvailability.Idle ||
      availability === RepairerAvailability.Busy ||
      availability === RepairerAvailability.Offline;
  }

  private static isKnownRepairReportResult(result: RepairReportResult): boolean {
    return result === RepairReportResult.Repaired ||
      result === RepairReportResult.TemporaryRestored ||
      result === RepairReportResult.Unresolved;
  }

  private static createLocalAvailableTasksResponse(radiusKm: number): ApiResponse<AvailableRepairTaskListResult> {
    return {
      success: true,
      data: LocalRepairTaskRepository.queryAvailableTasks(radiusKm),
      requestId: 'local-available-repair-tasks',
      timestamp: new Date().toISOString()
    };
  }

  private static createLocalAcceptTaskResponse(taskId: string): ApiResponse<RepairTaskAcceptResult> {
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
      '维修任务已分配给当前维修人员');
    return {
      success: true,
      data: result,
      requestId: 'local-repair-task-accept',
      timestamp: new Date().toISOString()
    };
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
      `维修结果：${RepairTaskService.formatRepairReportResult(form.result)}`);
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
      faultType: item.faultType as FaultType,
      severity: item.severity as FaultSeverity,
      distanceKm: item.distanceKm,
      location: item.location.address,
      submittedAt: item.submittedAt,
      status: item.status as RepairTaskStatus
    };
  }

  private static mapMyTask(item: MyRepairTaskApiSummary): MyRepairTaskSummary {
    return {
      id: item.id,
      taskNo: item.repairTaskNo,
      faultNo: item.faultReportNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      faultType: item.faultType as FaultType,
      severity: item.severity as FaultSeverity,
      acceptedAt: item.acceptedAt,
      status: item.status as RepairTaskStatus
    };
  }
}
