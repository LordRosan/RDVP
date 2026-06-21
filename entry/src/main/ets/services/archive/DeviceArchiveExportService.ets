import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { UIContext } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { ApiErrorCode, ApiResponse } from '../../models/common/ApiModels';
import { ApiClient } from '../common/ApiClient';

const MEDIA_WRITE_PERMISSION: Permissions = 'ohos.permission.WRITE_IMAGEVIDEO';

export interface DeviceArchiveExportVerificationForm {
  deviceId: string;
}

export interface DeviceArchiveExportVerificationResult {
  verified: boolean;
  deviceId: string;
  deviceCode: string;
}

export class DeviceArchiveExportService {
  static async verifyArchiveDetailExportRemoteFirst(
    form: DeviceArchiveExportVerificationForm
  ): Promise<ApiResponse<DeviceArchiveExportVerificationResult>> {
    const validationMessage = DeviceArchiveExportService.validateVerificationForm(form);
    if (validationMessage.length > 0) {
      return {
        success: false,
        error: {
          code: ApiErrorCode.ValidationFailed,
          message: validationMessage
        },
        timestamp: new Date().toISOString()
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveExportVerificationResult>();
    }

    const deviceId = encodeURIComponent(form.deviceId.trim());
    return ApiClient.request<DeviceArchiveExportVerificationResult>(
      `/api/v1/devices/${deviceId}/archive-export-verification`,
      'POST',
      true,
      undefined,
      false
    );
  }

  static async saveArchiveSnapshotToGallery(
    context: common.Context,
    uiContext: UIContext,
    componentId: string,
    deviceCode: string
  ): Promise<ApiResponse<string>> {
    if (componentId.trim().length === 0) {
      return DeviceArchiveExportService.createFailureResponse('档案详情导出失败');
    }

    let tempFilePath = '';
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      const mediaWriteGranted = await DeviceArchiveExportService.requestMediaWritePermission(context);
      if (!mediaWriteGranted) {
        return DeviceArchiveExportService.createFailureResponse('导出功能暂不可用，请稍后重试');
      }

      pixelMap = await uiContext.getComponentSnapshot().get(componentId, {
        scale: 2,
        waitUntilRenderFinished: true
      });
      const fileName = DeviceArchiveExportService.normalizeFileName(`${deviceCode}-archive-detail.png`);
      tempFilePath = `${context.cacheDir}/${fileName}`;
      const file = fileIo.openSync(tempFilePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        packer = image.createImagePacker();
        await packer.packToFile(pixelMap, file.fd, {
          format: 'image/png',
          quality: 100
        });
      } finally {
        fileIo.closeSync(file);
      }

      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      try {
        const request = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(
          context,
          fileUri.getUriFromPath(tempFilePath)
        );
        await helper.applyChanges(request);
      } finally {
        await helper.release();
      }

      return {
        success: true,
        data: fileName,
        requestId: 'local-archive-detail-export-save',
        timestamp: new Date().toISOString()
      };
    } catch (err) {
      return DeviceArchiveExportService.createFailureResponse('档案详情导出失败，请检查相册写入权限');
    } finally {
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (err) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (err) {
        }
      }
      DeviceArchiveExportService.deleteTempFile(tempFilePath);
    }
  }

  static async captureArchiveSnapshotPreview(
    uiContext: UIContext,
    componentId: string
  ): Promise<ApiResponse<string>> {
    if (componentId.trim().length === 0) {
      return DeviceArchiveExportService.createFailureResponse('档案详情预览失败');
    }

    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      pixelMap = await uiContext.getComponentSnapshot().get(componentId, {
        scale: 1,
        waitUntilRenderFinished: true
      });
      packer = image.createImagePacker();
      const bytes = await packer.packToData(pixelMap, {
        format: 'image/png',
        quality: 90
      });
      return {
        success: true,
        data: DeviceArchiveExportService.bytesToDataUri(bytes),
        requestId: 'local-archive-detail-export-preview',
        timestamp: new Date().toISOString()
      };
    } catch (err) {
      return DeviceArchiveExportService.createFailureResponse('档案详情预览失败');
    } finally {
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (err) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (err) {
        }
      }
    }
  }

  private static validateVerificationForm(form: DeviceArchiveExportVerificationForm): string {
    if (form.deviceId.trim().length === 0) {
      return '未获取设备档案';
    }

    return '';
  }

  private static bytesToDataUri(bytes: ArrayBuffer): string {
    const base64 = new util.Base64Helper();
    return `data:image/png;base64,${base64.encodeToStringSync(new Uint8Array(bytes))}`;
  }

  private static normalizeFileName(fileName: string): string {
    const safeName = fileName.trim().replace(/[\\/:*?"<>|]/g, '_');
    return safeName.toLowerCase().endsWith('.png') ? safeName : `${safeName}.png`;
  }

  private static createFailureResponse(message: string): ApiResponse<string> {
    return {
      success: false,
      error: {
        code: ApiErrorCode.InternalError,
        message
      },
      timestamp: new Date().toISOString()
    };
  }

  private static deleteTempFile(filePath: string): void {
    if (filePath.length === 0) {
      return;
    }

    try {
      fileIo.unlinkSync(filePath);
    } catch (err) {
    }
  }

  private static async requestMediaWritePermission(context: common.Context): Promise<boolean> {
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, [MEDIA_WRITE_PERMISSION]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }
}
