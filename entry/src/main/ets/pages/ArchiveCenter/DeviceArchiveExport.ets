import { common } from '@kit.AbilityKit';
import { AppSectionTitle } from '../../components/AppSectionTitle';
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
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { AuthService } from '../../services/identity/AuthService';
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
  @State currentTabIndex: number = 0;
  @State detailPassword: string = '';
  @State qrPassword: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State exporting: boolean = false;
  @State detailPreviewDataUri: string = '';
  @State qrExportResult: DeviceQrCodeExportResult | undefined = undefined;
  private clearingDetailPasswordAfterSuccess: boolean = false;
  private clearingQrPasswordAfterSuccess: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveExport)) {
      return;
    }

    this.syncTabFromActiveTab();
    this.loadArchiveContext();
  }

  onPageShow(): void {
    if (AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveExport)) {
      this.loadArchiveContext();
    }
  }

  build() {
    Stack() {
      Tabs({
        barPosition: BarPosition.End,
        index: this.currentTabIndex
      }) {
        TabContent() {
          this.ExportTab(EXPORT_TAB_DETAIL)
        }
        .tabBar(this.TabBarItem('导出详情', $r('sys.symbol.text_clipboard'), 0))

        TabContent() {
          this.ExportTab(EXPORT_TAB_QR)
        }
        .tabBar(this.TabBarItem('导出二维码', $r('sys.symbol.qrcode'), 1))
      }
      .barMode(BarMode.Fixed)
      .barHeight(78)
      .scrollable(false)
      .onChange((index: number) => {
        if (this.exporting) {
          this.syncTabFromActiveTab();
          return;
        }

        this.currentTabIndex = index;
        this.activeTab = index === 0 ? EXPORT_TAB_DETAIL : EXPORT_TAB_QR;
        this.message = '';
        this.messageTone = AppColors.Danger;
      })
      .height('100%')
      .width('100%')

      if (this.hasDevice) {
        this.HiddenDetailSnapshot()
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
  ExportTab(tab: string) {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader(tab)
          if (this.hasDevice) {
            this.ExportWorkspace(tab)
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
          bottom: AppSpacing.PageBottom
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
  ModeHeader(tab: string) {
    Column({ space: 5 }) {
      Text(tab === EXPORT_TAB_DETAIL ? '导出详情' : '导出二维码')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(tab === EXPORT_TAB_DETAIL ? 'Archive Detail Export' : 'Archive QR Code Export')
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
  ExportWorkspace(tab: string) {
    Column({ space: 16 }) {
      this.PreviewPanel(tab)
      this.PasswordField(tab)
      this.MessageText()
      this.ExportButton(tab)
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
  PreviewPanel(tab: string) {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '导出预览',
        subtitle: ''
      })

      Stack() {
        if (tab === EXPORT_TAB_DETAIL && this.detailPreviewDataUri.length > 0) {
          Image(this.detailPreviewDataUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else if (tab === EXPORT_TAB_QR && this.getQrExportImageDataUri().length > 0) {
          Image(this.getQrExportImageDataUri())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          SymbolGlyph(tab === EXPORT_TAB_DETAIL ? $r('sys.symbol.text_clipboard') : $r('sys.symbol.qrcode'))
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
  PasswordField(tab: string) {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '密码',
        subtitle: ''
      })

      TextInput({
        placeholder: '请输入密码',
        text: tab === EXPORT_TAB_DETAIL ? this.detailPassword : this.qrPassword
      })
        .type(InputType.Password)
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.exporting)
        .onChange((value: string) => {
          if (this.exporting) {
            return;
          }

          if (this.isClearingPasswordAfterSuccess(tab)) {
            this.clearPasswordAfterSuccessFlag(tab);
            this.setPassword(tab, value);
            if (value.length === 0) {
              return;
            }
          }

          this.setPassword(tab, value);
          this.message = '';
          this.messageTone = AppColors.Danger;
          this.clearExportPreviews();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
  ExportButton(tab: string) {
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
      this.exportByTab(tab);
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
  TabBarItem(label: string, icon: Resource, index: number) {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([this.currentTabIndex === index ? AppColors.Primary : AppColors.TextTertiary])

      Text(label)
        .fontSize(12)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? AppColors.Primary : AppColors.TextSecondary)
        .maxLines(1)
    }
    .width('100%')
    .height(62)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
      this.message = UiFeedbackService.requiredSelection('设备档案');
      this.messageTone = AppColors.Danger;
      return;
    }

    this.device = device;
    this.hasDevice = true;
  }

  syncTabFromActiveTab(): void {
    this.currentTabIndex = this.activeTab === EXPORT_TAB_DETAIL ? 0 : 1;
  }

  async exportByTab(tab: string): Promise<void> {
    if (this.exporting || !this.hasDevice) {
      return;
    }

    const password = this.getPassword(tab);
    if (password.length === 0) {
      this.message = UiFeedbackService.requiredInput('密码');
      this.messageTone = AppColors.Danger;
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
    try {
      const verified = await this.verifyPasswordForExport(password);
      if (!verified) {
        return;
      }

      if (tab === EXPORT_TAB_DETAIL) {
        await this.exportDetail(context);
      } else {
        await this.exportQrCode(context);
      }
    } finally {
      this.exporting = false;
    }
  }

  async verifyPasswordForExport(password: string): Promise<boolean> {
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(password);
    if (!response.success || response.data !== true) {
      this.message = UiFeedbackService.passwordVerificationError(response.error, '导出');
      this.messageTone = AppColors.Danger;
      return false;
    }

    return true;
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
    if (!previewResponse.success || previewResponse.data === undefined) {
      this.handleExportFailure(previewResponse.error === undefined ? '' : `${previewResponse.error.code}`);
      return;
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

    this.detailPreviewDataUri = previewResponse.data;
    this.handleExportSuccess(EXPORT_TAB_DETAIL);
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
    this.handleExportSuccess(EXPORT_TAB_QR);
  }

  handleExportSuccess(tab: string): void {
    this.markPasswordClearingAfterSuccess(tab);
    this.setPassword(tab, '');
    this.message = UiFeedbackService.operationSuccess('导出');
    this.messageTone = AppColors.Success;
    DashboardRefreshStore.notifyChanged();
  }

  handleExportFailure(errorCode: string): void {
    if (errorCode === 'SENSITIVE_OPERATION_VERIFICATION_REQUIRED') {
      this.message = UiFeedbackService.operationUnavailable('导出');
      this.messageTone = AppColors.Danger;
      return;
    }

    this.setExportUnavailableMessage();
  }

  clearExportPreviews(): void {
    this.detailPreviewDataUri = '';
    this.qrExportResult = undefined;
  }

  getPassword(tab: string): string {
    return tab === EXPORT_TAB_DETAIL ? this.detailPassword : this.qrPassword;
  }

  setPassword(tab: string, value: string): void {
    if (tab === EXPORT_TAB_DETAIL) {
      this.detailPassword = value;
      return;
    }

    this.qrPassword = value;
  }

  markPasswordClearingAfterSuccess(tab: string): void {
    if (tab === EXPORT_TAB_DETAIL) {
      this.clearingDetailPasswordAfterSuccess = true;
      return;
    }

    this.clearingQrPasswordAfterSuccess = true;
  }

  isClearingPasswordAfterSuccess(tab: string): boolean {
    return tab === EXPORT_TAB_DETAIL ? this.clearingDetailPasswordAfterSuccess : this.clearingQrPasswordAfterSuccess;
  }

  clearPasswordAfterSuccessFlag(tab: string): void {
    if (tab === EXPORT_TAB_DETAIL) {
      this.clearingDetailPasswordAfterSuccess = false;
      return;
    }

    this.clearingQrPasswordAfterSuccess = false;
  }

  setExportUnavailableMessage(): void {
    this.message = UiFeedbackService.operationUnavailable('导出');
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
        this.getUIContext().getPromptAction().showToast({ message: UiFeedbackService.operationUnavailable('页面跳转') });
      } catch (toastErr) {
      }
    }
  }
}
