import {
  ServiceMode,
  ServiceModeTransitionRequest,
  ServiceModeTransitionResult
} from '../models/ServiceModeModels';
import { ApiClient } from './ApiClient';
import { OfflineSyncService } from './OfflineSyncService';
import { WorkbenchService } from './WorkbenchService';
import { DeviceArchiveFlowStore } from '../stores/DeviceArchiveFlowStore';
import { OperationsFlowStore } from '../stores/OperationsFlowStore';
import { SessionStore } from '../stores/SessionStore';

export class ServiceModeTransitionService {
  static applyTransition(request: ServiceModeTransitionRequest): ServiceModeTransitionResult {
    const currentMode = ApiClient.getServiceMode();
    const currentBaseUrl = ApiClient.getBaseUrl();
    const normalizedBaseUrl = ApiClient.normalizeBaseUrlInput(request.apiBaseUrl);

    if (request.targetMode === ServiceMode.Online) {
      const validationMessage = ApiClient.validateRequiredBaseUrlInput(normalizedBaseUrl);
      if (validationMessage.length > 0) {
        return ServiceModeTransitionService.createFailure(request.targetMode, validationMessage);
      }
    }

    const modeChanged = currentMode !== request.targetMode;
    const endpointChanged = request.targetMode === ServiceMode.Online && currentBaseUrl !== normalizedBaseUrl;
    if (!modeChanged && !endpointChanged) {
      return {
        success: true,
        changed: false,
        requiresRelogin: false,
        targetMode: request.targetMode,
        message: request.targetMode === ServiceMode.Online ? '在线模式设置未变化' : '离线模式设置未变化'
      };
    }

    if (request.targetMode === ServiceMode.Offline) {
      const preparation = OfflineSyncService.prepareForOfflineTransition(request.reason);
      if (!preparation.success) {
        return ServiceModeTransitionService.createFailure(request.targetMode, preparation.message);
      }

      ApiClient.setServiceMode(ServiceMode.Offline);
      ServiceModeTransitionService.clearSessionScopedState();
      SessionStore.clearSession();
      return {
        success: true,
        changed: true,
        requiresRelogin: true,
        targetMode: request.targetMode,
        message: '已切换为离线模式，请重新登录以使用本地会话'
      };
    }

    const preparation = OfflineSyncService.prepareForOnlineRecovery(request.reason);
    if (!preparation.success) {
      return ServiceModeTransitionService.createFailure(request.targetMode, preparation.message);
    }

    ApiClient.setBaseUrl(normalizedBaseUrl);
    ApiClient.setServiceMode(ServiceMode.Online);
    ServiceModeTransitionService.clearSessionScopedState();
    SessionStore.clearSession();
    return {
      success: true,
      changed: true,
      requiresRelogin: true,
      targetMode: request.targetMode,
      message: '已切换为在线模式，请重新登录以使用后端会话'
    };
  }

  private static clearSessionScopedState(): void {
    DeviceArchiveFlowStore.clearFlow();
    OperationsFlowStore.clearFlow();
    WorkbenchService.clearCachedSummary();
  }

  private static createFailure(targetMode: ServiceMode, message: string): ServiceModeTransitionResult {
    return {
      success: false,
      changed: false,
      requiresRelogin: false,
      targetMode,
      message
    };
  }
}

