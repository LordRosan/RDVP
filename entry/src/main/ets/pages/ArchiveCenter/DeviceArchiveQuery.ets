import { abilityAccessCtrl } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { DeviceArchiveQueryMode, DeviceSummary } from '../../models/archive/DeviceModels';
import { ApiErrorCode } from '../../models/common/ApiModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { DeviceService } from '../../services/archive/DeviceService';
import { AppColors, AppSpacing } from '../../styles/AppTheme';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct DeviceArchiveQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State queryMode: DeviceArchiveQueryMode = DeviceArchiveQueryMode.Code;
  @State currentTabIndex: number = 0;
  @State deviceCode: string = '';
  @State qrContent: string = '';
  @State codeQueryMessage: string = '';
  @State qrActionMessage: string = '';
  @State qrQueryMessage: string = '';
  @State querying: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      return;
    }

    this.syncTabFromQueryMode();
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentTabIndex
    }) {
      TabContent() {
        this.QueryTab(DeviceArchiveQueryMode.Code)
      }
      .tabBar(this.TabBarItem('编号', $r('sys.symbol.rename'), 0))

      TabContent() {
        this.QueryTab(DeviceArchiveQueryMode.Qr)
      }
      .tabBar(this.TabBarItem('扫码', $r('sys.symbol.circle_viewfinder'), 1))
    }
    .barMode(BarMode.Fixed)
    .barHeight(78)
    .scrollable(false)
    .onChange((index: number) => {
      this.currentTabIndex = index;
      this.queryMode = index === 0 ? DeviceArchiveQueryMode.Code : DeviceArchiveQueryMode.Qr;
      this.clearMessages();
    })
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToMainPage();
    return true;
  }

  @Builder
  QueryTab(mode: DeviceArchiveQueryMode) {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.Header(mode)
          if (mode === DeviceArchiveQueryMode.Code) {
            this.DeviceCodePanel()
          } else {
            this.QrQueryPanel()
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
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .onClick(() => {
        this.backToMainPage();
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
  Header(mode: DeviceArchiveQueryMode) {
    Column({ space: 5 }) {
      Text(mode === DeviceArchiveQueryMode.Code ? '设备编号查询' : '二维码查询')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(mode === DeviceArchiveQueryMode.Code ? 'Device Code Lookup' : 'QR Code Lookup')
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
  DeviceCodePanel() {
    Column({ space: 16 }) {
      TextInput({
        placeholder: 'RDVP-DEVICE-XXXX',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.codeQueryMessage = '';
        })

      this.CodeQueryMessageText()
      this.ActionButton(this.querying ? '查询中' : '查询', $r('sys.symbol.magnifyingglass'), () => {
        this.submitDeviceCodeQuery();
      }, !this.querying)
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(24)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QrQueryPanel() {
    Column({ space: 16 }) {
      Stack() {
        if (this.qrContent.length > 0) {
          Column({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.qrcode'))
              .fontSize(52)
              .fontColor([AppColors.Primary])

            Text('已获取二维码')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)

            Text(this.getQrDeviceCodeDisplay())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height('100%')
        } else {
          Column({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.qrcode'))
              .fontSize(56)
              .fontColor([AppColors.Disabled])

            Text('等待二维码')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .aspectRatio(1)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(24)
      .border({
        width: 1,
        color: AppColors.Border
      })

      this.QrActionMessageText()

      Row({ space: 10 }) {
        Column() {
          this.ActionButton('扫描', $r('sys.symbol.circle_viewfinder'), () => {
            this.scanQrCode();
          }, !this.querying)
        }
        .layoutWeight(1)

        Column() {
          this.ActionButton('上传', $r('sys.symbol.picture'), () => {
            this.uploadQrImage();
          }, !this.querying)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.QrQueryMessageText()
      this.ActionButton(this.querying ? '查询中' : '查询', $r('sys.symbol.magnifyingglass'), () => {
        this.submitQrQuery();
      }, !this.querying)
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(24)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CodeQueryMessageText() {
    if (this.codeQueryMessage.length > 0) {
      InlineMessageSurface({
        message: this.codeQueryMessage,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  QrActionMessageText() {
    if (this.qrActionMessage.length > 0) {
      InlineMessageSurface({
        message: this.qrActionMessage,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  QrQueryMessageText() {
    if (this.qrQueryMessage.length > 0) {
      InlineMessageSurface({
        message: this.qrQueryMessage,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, action: () => void, enabled: boolean) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(label)
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
    .backgroundColor(enabled ? AppColors.Primary : AppColors.Disabled)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
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

  syncTabFromQueryMode(): void {
    this.currentTabIndex = this.queryMode === DeviceArchiveQueryMode.Code ? 0 : 1;
  }

  clearMessages(): void {
    this.codeQueryMessage = '';
    this.qrActionMessage = '';
    this.qrQueryMessage = '';
  }

  async submitDeviceCodeQuery(): Promise<void> {
    if (this.querying) {
      return;
    }

    this.codeQueryMessage = '';
    const validation = DeviceService.validateDeviceCodeQuery({
      deviceCode: this.deviceCode
    });
    if (!validation.valid) {
      this.codeQueryMessage = validation.message;
      return;
    }

    this.querying = true;
    const response = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: this.deviceCode
    });
    this.querying = false;

    if (!response.success) {
      const error = response.error;
      this.codeQueryMessage = this.normalizeCodeQueryError(error === undefined ? '' : `${error.code}`);
      return;
    }

    if (response.data !== undefined) {
      this.deviceCode = response.data.deviceCode;
      this.openDeviceArchiveDetail(response.data);
    }
  }

  async scanQrCode(): Promise<void> {
    this.qrActionMessage = '';
    this.qrQueryMessage = '';
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.qrActionMessage = '扫描取消或失败';
      return;
    }

    try {
      const cameraGranted = await this.ensureCameraPermission();
      if (!cameraGranted) {
        this.qrActionMessage = '扫描取消或失败';
        return;
      }

      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableAlbum: false
      });
      this.applyQrContent(result.originalValue, true);
    } catch (err) {
      this.qrActionMessage = '扫描取消或失败';
    }
  }

  async ensureCameraPermission(): Promise<boolean> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return false;
    }

    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);
      if (result.authResults.length === 0) {
        return false;
      }

      return result.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }

  async uploadQrImage(): Promise<void> {
    this.qrActionMessage = '';
    this.qrQueryMessage = '';

    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      if (selection.photoUris.length === 0) {
        this.qrActionMessage = '上传取消或失败';
        return;
      }

      const results = await detectBarcode.decode({
        uri: selection.photoUris[0]
      }, {
        scanTypes: [scanCore.ScanType.QR_CODE]
      });

      if (results.length === 0) {
        this.qrContent = '';
        this.qrActionMessage = '上传取消或失败';
        return;
      }

      this.applyQrContent(results[0].originalValue, false);
    } catch (err) {
      this.qrActionMessage = '上传取消或失败';
    }
  }

  async submitQrQuery(): Promise<void> {
    if (this.querying) {
      return;
    }

    this.qrQueryMessage = '';
    const validation = DeviceService.validateQrQuery({
      qrContent: this.qrContent
    });
    if (!validation.valid) {
      this.qrQueryMessage = validation.message;
      this.qrContent = '';
      return;
    }

    this.querying = true;
    const response = await DeviceService.queryByQrContentRemoteFirst({
      qrContent: this.qrContent
    });
    this.querying = false;

    if (!response.success) {
      const error = response.error;
      this.qrQueryMessage = this.normalizeQrQueryError(error === undefined ? '' : `${error.code}`);
      if (this.isQrValidationErrorCode(error === undefined ? '' : `${error.code}`)) {
        this.qrContent = '';
      }
      return;
    }

    if (response.data !== undefined) {
      this.openDeviceArchiveDetail(response.data);
    }
  }

  applyQrContent(content: string, scanned: boolean): void {
    const qrContent = DeviceService.normalizeQrContent(content);
    if (qrContent.length === 0) {
      this.qrContent = '';
      this.qrActionMessage = scanned ? '扫描取消或失败' : '上传取消或失败';
      return;
    }

    const validation = DeviceService.validateQrQuery({
      qrContent: qrContent
    });
    if (!validation.valid) {
      this.qrContent = '';
      this.qrActionMessage = '二维码无效，请重新扫描或上传';
      return;
    }

    this.qrContent = qrContent;
    this.qrActionMessage = '';
    this.qrQueryMessage = '';
  }

  normalizeCodeQueryError(errorCode: string): string {
    if (errorCode === 'DEVICE_CODE_INVALID' || errorCode === ApiErrorCode.BadRequest ||
      errorCode === ApiErrorCode.ValidationFailed) {
      return '设备编号无效，请重新输入';
    }

    if (errorCode === 'DEVICE_NOT_FOUND' || errorCode === ApiErrorCode.NotFound) {
      return '未查询到对应设备，请重新输入';
    }

    return '查询功能暂不可用，请稍后重试';
  }

  normalizeQrQueryError(errorCode: string): string {
    if (errorCode === 'DEVICE_NOT_FOUND') {
      return '未查询到对应设备，请重新扫描或上传';
    }

    if (this.isQrValidationErrorCode(errorCode) || errorCode === ApiErrorCode.BadRequest ||
      errorCode === ApiErrorCode.ValidationFailed || errorCode === ApiErrorCode.NotFound) {
      return '二维码无效，请重新扫描或上传';
    }

    return '查询功能暂不可用，请稍后重试';
  }

  isQrValidationErrorCode(errorCode: string): boolean {
    return errorCode.startsWith('QR_');
  }

  getQrDeviceCodeDisplay(): string {
    const segments = this.qrContent.split(':');
    if (segments.length >= 3 && segments[0] === 'RDVP') {
      return DeviceService.normalizeDeviceCode(segments[2]);
    }

    return '';
  }

  openDeviceArchiveDetail(device: DeviceSummary): void {
    DeviceArchiveFlowStore.startFlow(device);

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveDetail' });
    } catch (err) {
      if (this.queryMode === DeviceArchiveQueryMode.Code) {
        this.codeQueryMessage = '查询功能暂不可用，请稍后重试';
      } else {
        this.qrQueryMessage = '查询功能暂不可用，请稍后重试';
      }
    }
  }

  backToMainPage(): void {
    try {
      DeviceArchiveFlowStore.clearFlow();
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/MainPage' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
