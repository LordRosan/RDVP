import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { ApiResponse } from '../../shared/models/ApiModels';
import { ApiClient } from '../../shared/services/ApiClient';
import {
  ArchiveImageContentPayload,
  ArchiveImageDraft,
  ArchiveImageSubmissionPayload
} from '../models/ArchiveImageModels';
import { ArchiveImageSummary } from '../models/DeviceModels';

const MAX_ARCHIVE_IMAGES = 5;
const MAX_IMAGE_EDGE = 1600;
const MAX_COMPRESSED_BYTES = 1500000;
const JPEG_QUALITY = 82;

export class ArchiveImageService {
  static getMaximumImageCount(): number {
    return MAX_ARCHIVE_IMAGES;
  }

  static createDraftsFromSummaries(images: ArchiveImageSummary[]): ArchiveImageDraft[] {
    return images.map((item: ArchiveImageSummary): ArchiveImageDraft => ({
      id: item.id,
      previewUri: item.thumbnailDataUri
    }));
  }

  static buildSubmissionPayloads(images: ArchiveImageDraft[]): ArchiveImageSubmissionPayload[] {
    return images.map((item: ArchiveImageDraft): ArchiveImageSubmissionPayload => {
      if (item.id !== undefined && item.id.trim().length > 0) {
        return { id: item.id.trim() };
      }
      return { contentBase64: item.contentBase64 === undefined ? '' : item.contentBase64 };
    });
  }

  static async compressSelectedImage(uri: string): Promise<ArchiveImageDraft> {
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      const longestEdge = Math.max(info.size.width, info.size.height);
      const scale = longestEdge > MAX_IMAGE_EDGE ? MAX_IMAGE_EDGE / longestEdge : 1;
      const width = Math.max(1, Math.round(info.size.width * scale));
      const height = Math.max(1, Math.round(info.size.height * scale));
      pixelMap = await source.createPixelMap({
        desiredSize: { width, height }
      });
      packer = image.createImagePacker();
      const bytes = await packer.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: JPEG_QUALITY
      });
      if (bytes.byteLength === 0 || bytes.byteLength > MAX_COMPRESSED_BYTES) {
        throw new Error('ARCHIVE_IMAGE_SIZE_INVALID');
      }

      const base64 = new util.Base64Helper().encodeToStringSync(new Uint8Array(bytes));
      return {
        previewUri: `data:image/jpeg;base64,${base64}`,
        contentBase64: base64
      };
    } catch (err) {
      throw new Error('ARCHIVE_IMAGE_PROCESSING_FAILED');
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
      if (source !== undefined) {
        try {
          await source.release();
        } catch (err) {
        }
      }
    }
  }

  static async loadFullImage(imageId: string): Promise<ApiResponse<ArchiveImageContentPayload>> {
    return ApiClient.request<ArchiveImageContentPayload>(
      `/api/v1/archive-images/${encodeURIComponent(imageId.trim())}`,
      'GET',
      true
    );
  }
}
