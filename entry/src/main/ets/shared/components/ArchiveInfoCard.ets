import { DeviceStatus, DeviceSummary } from '../../archive/models/DeviceModels';
import { DeviceService } from '../../archive/services/DeviceService';
import { AppColors, AppRadii } from '../theme/AppTheme';
import { StatusInfoRow } from './StatusInfoRow';
import { ArchiveImageSummary } from '../../archive/models/DeviceModels';
import { ArchiveImageService } from '../../archive/services/ArchiveImageService';
import { UiFeedbackTone } from '../models/UiFeedbackModels';
import { UiFeedbackService } from '../services/UiFeedbackService';
import { InlineMessageSurface } from './InlineMessageSurface';

@Component
export struct ArchiveInfoCard {
  @Watch('onDeviceChanged')
  @Prop device: DeviceSummary = {
    id: '',
    deviceCode: '-',
    name: '-',
    images: [],
    deviceType: '-',
    model: '-',
    manufacturer: '-',
    commissionedAt: '-',
    managementDepartment: '-',
    location: {
      address: '-'
    },
    status: DeviceStatus.PendingVerification
  };
  @State expandedImageId: string = '';
  @State expandedImageDataUri: string = '';
  @State loadingImageId: string = '';
  @State imageMessage: string = '';
  private imageRequestVersion: number = 0;

  build() {
    Column() {
      this.InfoRow('设备编号', this.device.deviceCode)
      this.CardDivider()
      this.ImagePreview()
      this.CardDivider()
      this.InfoRow('设备名称', this.device.name)
      this.CardDivider()
      this.InfoRow('设备类型', this.device.deviceType)
      this.CardDivider()
      this.InfoRow('设备型号', this.device.model)
      this.CardDivider()
      this.InfoRow('生产厂商', this.device.manufacturer)
      this.CardDivider()
      this.InfoRow('启用日期', this.device.commissionedAt)
      this.CardDivider()
      this.InfoRow('管理部门', this.device.managementDepartment)
      this.CardDivider()
      this.InfoRow('设备位置', this.device.location.address)
      this.CardDivider()
      this.InfoRow('最近核验', DeviceService.formatTimestampForDisplay(this.device.lastVerificationTime))
    }
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  @Builder
  ImagePreview() {
    Column() {
      Row() {
        Text('设备图片')
          .fontSize(15)
          .fontColor(AppColors.TextPrimary)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        Text(`${this.device.images.length}张`)
          .fontSize(15)
          .fontColor(AppColors.TextSecondary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .height(54)
      .padding({ left: 18, right: 18 })
      .alignItems(VerticalAlign.Center)

      if (this.expandedImageDataUri.length > 0) {
        Image(this.expandedImageDataUri)
          .width('100%')
          .aspectRatio(1.6)
          .objectFit(ImageFit.Contain)
          .borderRadius(AppRadii.Medium)
          .backgroundColor(AppColors.FieldBackground)
          .margin({ left: 18, right: 18, bottom: 10 })
          .onClick(() => this.collapseImage())
      }

      if (this.device.images.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.device.images, (item: ArchiveImageSummary) => {
              Stack({ alignContent: Alignment.Center }) {
                Image(item.thumbnailDataUri)
                  .width(72)
                  .height(54)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(AppRadii.Small)

                if (this.loadingImageId === item.id) {
                  LoadingProgress()
                    .width(22)
                    .height(22)
                    .color(AppColors.Primary)
                }
              }
              .width(80)
              .height(60)
              .border({
                width: this.expandedImageId === item.id ? 2 : 1,
                color: this.expandedImageId === item.id ? AppColors.Primary : AppColors.Border
              })
              .borderRadius(AppRadii.Small)
              .onClick(() => this.toggleImage(item))
            }, (item: ArchiveImageSummary) => item.id)
          }
          .justifyContent(FlexAlign.Start)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 12 })
      } else {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(20)
            .fontColor([AppColors.TextSecondary])

          Text('未设置')
            .fontSize(15)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
        }
        .height(56)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(AppRadii.Medium)
        .border({ width: 1, color: AppColors.Border })
        .margin({ left: 18, right: 18, bottom: 12 })
        .alignItems(VerticalAlign.Center)
      }

      if (this.imageMessage.length > 0) {
        InlineMessageSurface({
          message: this.imageMessage,
          tone: UiFeedbackTone.Danger
        })
        .margin({ left: 18, right: 18, bottom: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  async toggleImage(item: ArchiveImageSummary): Promise<void> {
    if (this.expandedImageId === item.id) {
      this.collapseImage();
      return;
    }

    const requestVersion = this.imageRequestVersion + 1;
    this.imageRequestVersion = requestVersion;
    this.loadingImageId = item.id;
    this.imageMessage = '';
    try {
      const response = await ArchiveImageService.loadFullImage(item.id);
      if (this.imageRequestVersion !== requestVersion || this.loadingImageId !== item.id) {
        return;
      }
      if (response.success && response.data !== undefined) {
        this.expandedImageId = item.id;
        this.expandedImageDataUri = response.data.dataUri;
      } else {
        this.imageMessage = UiFeedbackService.operationUnavailable('图片加载');
      }
    } catch (err) {
      if (this.imageRequestVersion !== requestVersion || this.loadingImageId !== item.id) {
        return;
      }
      this.imageMessage = UiFeedbackService.operationUnavailable('图片加载');
    }
    this.loadingImageId = '';
  }

  collapseImage(): void {
    this.imageRequestVersion += 1;
    this.expandedImageId = '';
    this.expandedImageDataUri = '';
    this.loadingImageId = '';
    this.imageMessage = '';
  }

  onDeviceChanged(): void {
    this.collapseImage();
  }

  @Builder
  InfoRow(label: string, value: string) {
    StatusInfoRow({
      label,
      value: this.safeText(value),
      tone: AppColors.TextSecondary,
      valueMaxLines: 2,
      verticalPadding: 12
    })
  }

  safeText(value: string): string {
    if (value === undefined || value.length === 0) {
      return '-';
    }

    return value;
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
      })
  }
}
