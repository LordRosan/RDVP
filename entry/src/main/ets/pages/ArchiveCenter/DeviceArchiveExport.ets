import { common } from '@kit.AbilityKit';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../../models/archive/DeviceModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { DeviceArchiveExportService } from '../../services/archive/DeviceArchiveExportService';
import {
  DeviceQrCodeExportResult,
  DeviceQrCodeExportService
} from '../../services/archive/DeviceQrCodeExportService';
import { DeviceService } from '../../services/archive/DeviceService';
import { DashboardRefreshStore } from '../../stores/DashboardRefreshStore';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

const ARCHIVE_EXPORT_PREVIEW_BODY_ID = 'rdvp_archive_export_preview_body';
const EXPORT_TAB_DETAIL = 'DETAIL';
const EXPORT_TAB_QR = 'QR';

@Entry
@Component
struct DeviceArchiveExport {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State device: DeviceSummary = {
    id: '',
    deviceCode: '-',
    name: '-',
    model: '-',
    manufacturer: '-',
    location: {
      address: '-'
    },
    status: DeviceStatus.PendingVerification
  };
  @State hasDevice: boolean = false;
  @State activeTab: string = EXPORT_TAB_DETAIL;
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State exporting: boolean = false;
  @State detailPreviewDataUri: string = '';
  @State qrExportResult: DeviceQrCodeExportResult | undefined = undefined;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveExport)) {
      return;
    }

    this.loadArchiveContext();
  }

  onPageShow(): void {
    if (AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveExport)) {
      this.loadArchiveContext();
    }
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          this.PageTitleBar()

          Column({ space: 18 }) {
            this.ModeHeader()
            if (this.hasDevice) {
              this.ExportWorkspace()
            } else {
              this.EmptyPanel()
            }
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .padding({
            left: AppSpacing.PageX,
            right: AppSpacing.PageX,
            top: 0,
            bottom: 120
          })
          .width('100%')
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .height('100%')
      .width('100%')

      if (this.hasDevice) {
        this.HiddenDetailSnapshot()
        this.BottomTabs()
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToDetail();
    return true;
  }

  @Builder
  PageTitleBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([AppColors.TextPrimary])
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.SurfaceRaised)
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToDetail();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: AppSpacing.PageX,
      right: AppSpacing.PageX
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('导出设备档案')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Device Archive Export')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: 6
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ExportWorkspace() {
    Column({ space: 16 }) {
      this.PreviewPanel()
      this.MessageText()
      this.ExportButton()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HiddenDetailSnapshot() {
    Column() {
      this.DetailSnapshotBody()
    }
    .id(ARCHIVE_EXPORT_PREVIEW_BODY_ID)
    .width('100%')
    .position({
      x: '-120%',
      y: 0
    })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  DetailSnapshotBody() {
    Column({ space: 14 }) {
      StatusInfoRow({ label: '设备编号', value: this.device.deviceCode, tone: AppColors.TextSecondary })
      this.CardDivider()
      StatusInfoRow({ label: '设备名称', value: this.device.name, tone: AppColors.TextSecondary })
      this.CardDivider()
      StatusInfoRow({ label: '设备型号', value: this.device.model, tone: AppColors.TextSecondary })
      this.CardDivider()
      StatusInfoRow({ label: '生产厂商', value: this.device.manufacturer, tone: AppColors.TextSecondary })
      this.CardDivider()
      StatusInfoRow({ label: '设备位置', value: this.device.location.address, tone: AppColors.TextSecondary })
      this.CardDivider()
      StatusInfoRow({
        label: '最近核验',
        value: DeviceService.formatTimestampForDisplay(this.device.lastVerificationTime),
        tone: AppColors.TextSecondary
      })
      this.CardDivider()
      StatusInfoRow({
        label: '设备状态',
        value: DeviceService.formatDeviceStatus(this.device.status),
        tone: DeviceService.getDeviceStatusTone(this.device.status)
      })
      this.CardDivider()
      StatusInfoRow({
        label: '档案状态',
        value: DeviceService.formatArchiveRequestLockReason(this.device),
        tone: DeviceService.isArchiveRequestLocked(this.device) ? AppColors.Danger : AppColors.Success
      })
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
  }

  @Builder
  PreviewPanel() {
    Column({ space: 12 }) {
      Stack() {
        if (this.activeTab === EXPORT_TAB_DETAIL && this.detailPreviewDataUri.length > 0) {
          Image(this.detailPreviewDataUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else if (this.activeTab === EXPORT_TAB_QR && this.getQrExportImageDataUri().length > 0) {
          Image(this.getQrExportImageDataUri())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          SymbolGlyph(this.activeTab === EXPORT_TAB_DETAIL ? $r('sys.symbol.text_clipboard') : $r('sys.symbol.qrcode'))
            .fontSize(58)
            .fontColor([AppColors.TextSecondary])
        }
      }
      .width('100%')
      .aspectRatio(1)
      .padding(16)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Border
      })
    }
    .width('100%')
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: this.messageTone
      })
    }
  }

  @Builder
  ExportButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.exporting }) {
      Row({ space: 8 }) {
        Image($r('sys.media.ohos_save_button_line'))
          .width(20)
          .height(20)
          .fillColor(AppColors.OnPrimary)

        Text(this.exporting ? '导出中' : '导出')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(this.exporting ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.exporting)
    .onClick(() => {
      this.exportCurrentTab();
    })
  }

  @Builder
  EmptyPanel() {
    Column({ space: 12 }) {
      this.MessageText()
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  BottomTabs() {
    Column() {
      Row({ space: 10 }) {
        this.TabButton(EXPORT_TAB_DETAIL, '导出详情', $r('sys.symbol.text_clipboard'))
        this.TabButton(EXPORT_TAB_QR, '导出二维码', $r('sys.symbol.qrcode'))
      }
      .width('100%')
      .padding({
        left: 10,
        right: 10,
        top: 10,
        bottom: 10
      })
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .padding({
      left: AppSpacing.PageX,
      right: AppSpacing.PageX,
      bottom: 20
    })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  TabButton(tab: string, label: string, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.exporting }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.activeTab === tab ? AppColors.OnPrimary : AppColors.TextSecondary])

        Text(label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.activeTab === tab ? AppColors.OnPrimary : AppColors.TextSecondary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(48)
    .backgroundColor(this.activeTab === tab ? AppColors.Primary : AppColors.FieldBackground)
    .enabled(!this.exporting)
    .onClick(() => {
      if (this.exporting) {
        return;
      }

      this.activeTab = tab;
      this.message = '';
      this.messageTone = AppColors.Danger;
    })
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

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      this.hasDevice = false;
      this.message = '未获取设备档案，请重新查询';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.device = device;
    this.hasDevice = true;
  }

  async exportCurrentTab(): Promise<void> {
    if (this.exporting || !this.hasDevice) {
      return;
    }

    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.setExportUnavailableMessage();
      return;
    }

    this.exporting = true;
    this.message = '';
    this.messageTone = AppColors.Danger;
    if (this.activeTab === EXPORT_TAB_DETAIL) {
      await this.exportDetail(context);
    } else {
      await this.exportQrCode(context);
    }
    this.exporting = false;
  }

  async exportDetail(context: common.Context): Promise<void> {
    const verifyResponse = await DeviceArchiveExportService.verifyArchiveDetailExportRemoteFirst({
      deviceId: this.device.id
    });
    if (!verifyResponse.success || verifyResponse.data === undefined || !verifyResponse.data.verified) {
      this.handleExportFailure(verifyResponse.error === undefined ? '' : `${verifyResponse.error.code}`);
      return;
    }

    const previewResponse = await DeviceArchiveExportService.captureArchiveSnapshotPreview(
      this.getUIContext(),
      ARCHIVE_EXPORT_PREVIEW_BODY_ID
    );
    if (previewResponse.success && previewResponse.data !== undefined) {
      this.detailPreviewDataUri = previewResponse.data;
    }

    const saveResponse = await DeviceArchiveExportService.saveArchiveSnapshotToGallery(
      context,
      this.getUIContext(),
      ARCHIVE_EXPORT_PREVIEW_BODY_ID,
      verifyResponse.data.deviceCode
    );
    if (!saveResponse.success) {
      this.handleExportFailure(saveResponse.error === undefined ? '' : `${saveResponse.error.code}`);
      return;
    }

    this.handleExportSuccess();
  }

  async exportQrCode(context: common.Context): Promise<void> {
    const exportResponse = await DeviceQrCodeExportService.exportQrCodeRemoteFirst({
      deviceId: this.device.id
    });
    if (!exportResponse.success || exportResponse.data === undefined) {
      this.handleExportFailure(exportResponse.error === undefined ? '' : `${exportResponse.error.code}`);
      return;
    }

    const saveResponse = await DeviceQrCodeExportService.saveImageToGallery(context, exportResponse.data);
    if (!saveResponse.success) {
      this.handleExportFailure(saveResponse.error === undefined ? '' : `${saveResponse.error.code}`);
      return;
    }

    this.qrExportResult = exportResponse.data;
    this.handleExportSuccess();
  }

  handleExportSuccess(): void {
    this.message = '导出成功，已保存至图库';
    this.messageTone = AppColors.Success;
    DashboardRefreshStore.notifyChanged();
  }

  handleExportFailure(errorCode: string): void {
    if (errorCode === 'SENSITIVE_OPERATION_VERIFICATION_REQUIRED') {
      this.message = '导出功能暂不可用，请稍后重试';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.setExportUnavailableMessage();
  }

  setExportUnavailableMessage(): void {
    this.message = '导出功能暂不可用，请稍后重试';
    this.messageTone = AppColors.Danger;
  }

  getQrExportImageDataUri(): string {
    if (this.qrExportResult === undefined) {
      return '';
    }

    return DeviceQrCodeExportService.getImageDataUri(this.qrExportResult);
  }

  backToDetail(): void {
    if (!MainPageNavigator.backOrReplace(this.getUIContext(), 'pages/ArchiveCenter/DeviceArchiveDetail', true)) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
