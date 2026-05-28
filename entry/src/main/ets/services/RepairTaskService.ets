import { ApiResponse } from '../models/ApiModels';
import {
  AvailableRepairTaskListResult,
  AvailableRepairTaskQuery,
  MyRepairTaskListResult,
  RepairerAvailability,
  RepairReportForm,
  RepairReportRecord,
  RepairReportResult,
  RepairTaskAcceptResult,
  RepairTaskStatus,
  RepairTaskValidationResult
} from '../models/RepairTaskModels';
import { ApiClient } from './ApiClient';

const DEFAULT_RADIUS_KM = 10;
const MIN_RADIUS_KM = 1;
const MAX_RADIUS_KM = 100;
const MAX_REPAIR_PROCESS_LENGTH = 1000;
const MAX_PARTS_USED_LENGTH = 500;

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
      return ApiClient.createServiceUnavailableResponse<AvailableRepairTaskListResult>();
    }

    return ApiClient.createServiceUnavailableResponse<AvailableRepairTaskListResult>();
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
      return ApiClient.createServiceUnavailableResponse<RepairTaskAcceptResult>();
    }

    return ApiClient.createServiceUnavailableResponse<RepairTaskAcceptResult>();
  }

  static queryMyRepairTasks(): ApiResponse<MyRepairTaskListResult> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<MyRepairTaskListResult>();
    }

    return ApiClient.createServiceUnavailableResponse<MyRepairTaskListResult>();
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
      return ApiClient.createServiceUnavailableResponse<RepairReportRecord>();
    }

    return ApiClient.createServiceUnavailableResponse<RepairReportRecord>();
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
}
