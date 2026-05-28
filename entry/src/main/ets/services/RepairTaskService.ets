import { ApiResponse } from '../models/ApiModels';
import {
  AvailableRepairTaskListResult,
  AvailableRepairTaskQuery,
  RepairerAvailability,
  RepairTaskAcceptResult,
  RepairTaskStatus,
  RepairTaskValidationResult
} from '../models/RepairTaskModels';
import { ApiClient } from './ApiClient';

const DEFAULT_RADIUS_KM = 10;
const MIN_RADIUS_KM = 1;
const MAX_RADIUS_KM = 100;

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

  private static isKnownAvailability(availability: RepairerAvailability): boolean {
    return availability === RepairerAvailability.Idle ||
      availability === RepairerAvailability.Busy ||
      availability === RepairerAvailability.Offline;
  }
}
