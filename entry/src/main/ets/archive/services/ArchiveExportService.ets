import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { UIContext } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { ApiErrorCode, ApiResponse } from '../../shared/models/ApiModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

const MEDIA_WRITE_PERMISSION: Permissions = 'ohos.permission.WRITE_IMAGEVIDEO';

export interface ArchiveExportVerificationForm {
  deviceId: string;
}

export interface ArchiveExportVerificationResult {
  verified: boolean;
  deviceId: string;
  deviceCode: string;
}

export class ArchiveExportService {
  static async verifyArchiveDetailExportRemoteFirst(
    form: ArchiveExportVerificationForm
  ): Promise<ApiResponse<ArchiveExportVerificationResult>> {
    const validationMessage = ArchiveExportService.validateVerificationForm(form);
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
      return ApiClient.createServiceUnavailableResponse<ArchiveExportVerificationResult>();
    }

    const deviceId = encodeURIComponent(form.deviceId.trim());
    return ApiClient.request<ArchiveExportVerificationResult>(
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
      return ArchiveExportService.createFailureResponse(UiFeedbackService.operationUnavailable('导出'));
    }

    let tempFilePath = '';
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      const mediaWriteGranted = await ArchiveExportService.requestMediaWritePermission(context);
      if (!mediaWriteGranted) {
        return ArchiveExportService.createFailureResponse(UiFeedbackService.operationUnavailable('导出'));
      }

      pixelMap = await uiContext.getComponentSnapshot().get(componentId, {
        scale: 2,
        waitUntilRenderFinished: true
      });
      const fileName = ArchiveExportService.normalizeFileName(`${deviceCode}-archive-detail.png`);
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
      return ArchiveExportService.createFailureResponse(UiFeedbackService.operationUnavailable('导出'));
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
      ArchiveExportService.deleteTempFile(tempFilePath);
    }
  }

  static async captureArchiveSnapshotPreview(
    uiContext: UIContext,
    componentId: string
  ): Promise<ApiResponse<string>> {
    if (componentId.trim().length === 0) {
      return ArchiveExportService.createFailureResponse(UiFeedbackService.operationUnavailable('导出'));
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
        data: ArchiveExportService.bytesToDataUri(bytes),
        requestId: 'local-archive-detail-export-preview',
        timestamp: new Date().toISOString()
      };
    } catch (err) {
      return ArchiveExportService.createFailureResponse(UiFeedbackService.operationUnavailable('导出'));
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

  private static validateVerificationForm(form: ArchiveExportVerificationForm): string {
    if (form.deviceId.trim().length === 0) {
      return UiFeedbackService.requiredSelection('档案');
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
