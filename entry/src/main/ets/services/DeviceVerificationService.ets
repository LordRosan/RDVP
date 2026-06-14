import { ApiResponse } from '../models/ApiModels';
import { FaultStatus } from '../models/FaultModels';
import {
  DeviceVerificationForm,
  DeviceVerificationFaultReportForm,
  DeviceVerificationFaultReportRecord,
  DeviceVerificationRecord,
  DeviceVerificationValidationResult,
  VerificationResult
} from '../models/VerificationModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { FaultReportService } from './FaultReportService';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;

interface DeviceVerificationApiResult {
  id: string;
  result: string;
  description: string;
  remark?: string;
  verifiedAt: string;
  createdAt: string;
}

interface FaultReportApiResult {
  id: string;
  faultReportNo: string;
  status: FaultStatus;
  createdAt: string;
}

interface DeviceVerificationFaultReportApiResult {
  verificationRecord: DeviceVerificationApiResult;
  faultReport: FaultReportApiResult;
}

export class DeviceVerificationService {
  static normalizeText(value: string): string {
    return value.trim();
  }

  static validateVerificationForm(form: DeviceVerificationForm): DeviceVerificationValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.deviceCode
    });

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message
      };
    }

    if (!DeviceVerificationService.isKnownResult(form.result)) {
      return {
        valid: false,
        message: '请选择核验结果'
      };
    }

    const description = DeviceVerificationService.normalizeText(form.description);
    if (description.length === 0) {
      return {
        valid: false,
        message: '请输入现场描述'
      };
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: '现场描述不能超过500字'
      };
    }

    const remark = DeviceVerificationService.normalizeText(form.remark ?? '');
    if (remark.length > MAX_REMARK_LENGTH) {
      return {
        valid: false,
        message: '备注不能超过300字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static validateVerificationFaultReportForm(form: DeviceVerificationFaultReportForm): DeviceVerificationValidationResult {
    const verificationValidation = DeviceVerificationService.validateVerificationForm(form.verification);
    if (!verificationValidation.valid) {
      return verificationValidation;
    }

    if (form.verification.result === VerificationResult.Normal) {
      return {
        valid: false,
        message: '正常核验不需要提交报修信息'
      };
    }

    const faultReportValidation = FaultReportService.validateFaultReportForm(form.faultReport);
    if (!faultReportValidation.valid) {
      return {
        valid: false,
        message: faultReportValidation.message
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static async submitVerificationRemoteFirst(form: DeviceVerificationForm): Promise<ApiResponse<DeviceVerificationRecord>> {
    const validation = DeviceVerificationService.validateVerificationForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceVerificationRecord>();
    }

    const verifiedAt = new Date().toISOString();
    return DeviceVerificationService.submitVerificationToBackend(form, verifiedAt);
  }

  static async submitVerificationWithFaultReportRemoteFirst(
    form: DeviceVerificationFaultReportForm
  ): Promise<ApiResponse<DeviceVerificationFaultReportRecord>> {
    const validation = DeviceVerificationService.validateVerificationFaultReportForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_FAULT_REPORT_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceVerificationFaultReportRecord>();
    }

    const verifiedAt = new Date().toISOString();
    return DeviceVerificationService.submitVerificationFaultReportToBackend(form, verifiedAt);
  }

  private static async submitVerificationToBackend(
    form: DeviceVerificationForm,
    verifiedAt: string
  ): Promise<ApiResponse<DeviceVerificationRecord>> {
    const deviceResponse = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: form.deviceCode
    });
    if (!deviceResponse.success || deviceResponse.data === undefined) {
      return {
        success: false,
        error: deviceResponse.error,
        requestId: deviceResponse.requestId,
        timestamp: deviceResponse.timestamp
      };
    }

    const response = await ApiClient.request<DeviceVerificationApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-records`,
      'POST',
      true,
      JSON.stringify({
        result: form.result,
        description: DeviceVerificationService.normalizeText(form.description),
        remark: DeviceVerificationService.normalizeText(form.remark ?? ''),
        verifiedAt
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
          code: 'DEVICE_VERIFICATION_RESPONSE_INVALID',
          message: '核验记录响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        id: response.data.id,
        deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
        result: response.data.result as VerificationResult,
        description: response.data.description,
        remark: response.data.remark,
        submittedAt: response.data.createdAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static async submitVerificationFaultReportToBackend(
    form: DeviceVerificationFaultReportForm,
    verifiedAt: string
  ): Promise<ApiResponse<DeviceVerificationFaultReportRecord>> {
    const deviceResponse = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: form.verification.deviceCode
    });
    if (!deviceResponse.success || deviceResponse.data === undefined) {
      return {
        success: false,
        error: deviceResponse.error,
        requestId: deviceResponse.requestId,
        timestamp: deviceResponse.timestamp
      };
    }

    const response = await ApiClient.request<DeviceVerificationFaultReportApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-records/fault-report`,
      'POST',
      true,
      JSON.stringify({
        result: form.verification.result,
        description: DeviceVerificationService.normalizeText(form.verification.description),
        remark: DeviceVerificationService.normalizeText(form.verification.remark ?? ''),
        verifiedAt,
        faultType: form.faultReport.faultType,
        severity: form.faultReport.severity,
        occurredAt: FaultReportService.normalizeText(form.faultReport.occurredAt),
        faultDescription: FaultReportService.normalizeText(form.faultReport.description),
        sceneCondition: FaultReportService.normalizeText(form.faultReport.sceneCondition)
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
          code: 'DEVICE_VERIFICATION_FAULT_REPORT_RESPONSE_INVALID',
          message: '核验与报修响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        verificationRecord: {
          id: response.data.verificationRecord.id,
          deviceCode: DeviceService.normalizeDeviceCode(form.verification.deviceCode),
          result: response.data.verificationRecord.result as VerificationResult,
          description: response.data.verificationRecord.description,
          remark: response.data.verificationRecord.remark,
          submittedAt: response.data.verificationRecord.createdAt
        },
        faultReport: {
          id: response.data.faultReport.id,
          reportNo: response.data.faultReport.faultReportNo,
          deviceCode: DeviceService.normalizeDeviceCode(form.faultReport.deviceCode),
          faultType: form.faultReport.faultType,
          severity: form.faultReport.severity,
          status: response.data.faultReport.status as FaultStatus,
          submittedAt: response.data.faultReport.createdAt
        }
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatVerificationResult(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return '正常';
      case VerificationResult.Abnormal:
        return '异常';
      default:
        return '-';
    }
  }

  private static isKnownResult(result: VerificationResult): boolean {
    return result === VerificationResult.Normal ||
      result === VerificationResult.Abnormal;
  }
}
