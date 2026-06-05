import { AppColors } from '../../styles/AppTheme';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { PermissionCode } from '../../models/PermissionModels';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceQueryMode, DeviceSummary } from '../../models/DeviceModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceService } from '../../services/DeviceService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { AuthGuard } from '../../utils/AuthGuard';

const DEVICE_ARCHIVE_QUERY_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '查询设备档案',
    items: [
      {
        label: '设备编号',
        description: '使用系统内唯一编号查询设备档案，适合已知编号或现场记录明确的场景'
      },
      {
        label: '二维码',
        description: '通过扫描或上传二维码解析设备标识和防伪信息，用于快速定位设备档案'
      },
      {
        label: '档案详情',
        description: '查询成功后进入设备档案详情，再根据档案状态决定是否发起变更申请'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State queryMode: DeviceQueryMode = DeviceQueryMode.Code;
  @State deviceCode: string = '';
  @State qrContent: string = '';
  @State codeQueryMessage: string = '';
  @State qrActionMessage: string = '';
  @State qrQueryMessage: string = '';
  @State normalizedDeviceCode: string = '-';
  @State querying: boolean = false;
  private queryInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '查询设备档案说明',
      sections: DEVICE_ARCHIVE_QUERY_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceRead);
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.QueryPanel()
          this.ResultPanel()
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({
          left: 24,
          right: 24,
          top: 0,
          bottom: 28
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
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToWorkbench();
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
      .backgroundColor(AppColors.Surface)
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .onClick(() => {
        this.backToWorkbench();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 24,
      right: 24
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text('查询设备档案')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          this.InfoButton(() => {
            this.showQueryInfoDialog();
          })
        }
        .alignItems(VerticalAlign.Center)

        Text(this.getModeSubtitle())
          .fontSize(15)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.ModeSwitchButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      top: 0,
      bottom: 2
    })
  }

  @Builder
  ModeSwitchButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (this.queryMode === DeviceQueryMode.Code) {
        SymbolGlyph($r('sys.symbol.circle_viewfinder'))
          .fontSize(31)
          .fontColor([AppColors.TextPrimary])
      } else {
        SymbolGlyph($r('sys.symbol.rename'))
          .fontSize(31)
          .fontColor([AppColors.TextPrimary])
      }
    }
    .width(58)
    .height(58)
    .backgroundColor(AppColors.Surface)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      this.switchQueryMode();
    })
  }

  @Builder
  QueryPanel() {
    if (this.queryMode === DeviceQueryMode.Code) {
      this.DeviceCodePanel()
    } else {
      this.QrQueryPanel()
    }
  }

  @Builder
  DeviceCodePanel() {
    Column({ space: 14 }) {
      Text('设备编号查询')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      TextInput({
        placeholder: '输入设备编号',
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
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
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
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QrQueryPanel() {
    Column({ space: 14 }) {
      Text('二维码查询')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Stack() {
        if (this.qrContent.length > 0) {
          Column({ space: 14 }) {
            SymbolGlyph($r('sys.symbol.qrcode'))
              .fontSize(52)
              .fontColor([AppColors.Primary])

            Text('已识别二维码')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)

            Column({ space: 8 }) {
              this.QrSummaryLine('设备编号', this.getQrDeviceCodeDisplay())
              this.QrSummaryLine('签名指纹', this.getQrSignatureFingerprint())
            }
            .width('100%')
            .padding({
              left: 18,
              right: 18
            })
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

            Text('未获取二维码内容')
              .fontSize(15)
              .fontColor(AppColors.TextTertiary)
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
      .borderRadius(22)
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
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CodeQueryMessageText() {
    if (this.codeQueryMessage.length > 0) {
      Text(this.codeQueryMessage)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QrActionMessageText() {
    if (this.qrActionMessage.length > 0) {
      Text(this.qrActionMessage)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QrQueryMessageText() {
    if (this.qrQueryMessage.length > 0) {
      Text(this.qrQueryMessage)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QrSummaryLine(label: string, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)

      Text(value)
        .fontSize(14)
        .fontColor(AppColors.TextSecondary)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(24)
    .alignItems(VerticalAlign.Center)
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
  InfoButton(action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor([AppColors.TextPrimary])
    }
    .width(28)
    .height(28)
    .backgroundColor(AppColors.Transparent)
    .onClick(() => {
      action();
    })
  }

  @Builder
  ResultPanel() {
    Column({ space: 10 }) {
      Text('查询状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        this.QueryMethodStatusRow()
        this.CardDivider()
        this.QueryValueStatusRow()
        this.CardDivider()
        StatusInfoRow({
          label: '服务模式',
          value: ApiClient.getRuntimeStatusLabel(),
          tone: ApiClient.getRuntimeStatusTone()
        })
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  QueryMethodStatusRow() {
    Row() {
      Text('查询方式')
        .fontSize(15)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.queryMode === DeviceQueryMode.Code ? '设备编号' : '二维码')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(54)
    .padding({
      left: 18,
      right: 18
    })
    .width('100%')
  }

  @Builder
  QueryValueStatusRow() {
    Row() {
      Text(this.queryMode === DeviceQueryMode.Code ? '标准编号' : '二维码摘要')
        .fontSize(15)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.queryMode === DeviceQueryMode.Code ? this.normalizedDeviceCode : this.getQrPreview())
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(54)
    .padding({
      left: 18,
      right: 18
    })
    .width('100%')
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

  switchQueryMode(): void {
    this.codeQueryMessage = '';
    this.qrActionMessage = '';
    this.qrQueryMessage = '';
    this.queryMode = this.queryMode === DeviceQueryMode.Code ? DeviceQueryMode.Qr : DeviceQueryMode.Code;
  }

  getModeTitle(): string {
    return '查询设备档案';
  }

  getModeSubtitle(): string {
    return this.queryMode === DeviceQueryMode.Code ? '输入设备编号定位设备档案' : '扫描或上传二维码定位设备档案';
  }

  async submitDeviceCodeQuery(): Promise<void> {
    if (this.querying) {
      return;
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    this.querying = true;
    const response = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: this.deviceCode
    });
    this.querying = false;

    if (!response.success) {
      const error = response.error;
      this.codeQueryMessage = error ? error.message : '查询设备档案失败';
      return;
    }

    if (response.data !== undefined) {
      this.openDeviceArchiveDetail(response.data);
    }
  }

  async scanQrCode(): Promise<void> {
    this.qrActionMessage = '';
    this.qrQueryMessage = '';
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.qrActionMessage = '无法获取页面上下文';
      return;
    }

    try {
      const cameraGranted = await this.ensureCameraPermission();
      if (!cameraGranted) {
        this.qrActionMessage = '请授权相机权限后再扫描二维码';
        return;
      }

      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableAlbum: false
      });
      this.applyQrContent(result.originalValue);
    } catch (err) {
      this.qrActionMessage = '扫码取消或失败';
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
        this.qrActionMessage = '未选择图片';
        return;
      }

      const results = await detectBarcode.decode({
        uri: selection.photoUris[0]
      }, {
        scanTypes: [scanCore.ScanType.QR_CODE]
      });

      if (results.length === 0) {
        this.qrContent = '';
        this.qrActionMessage = '未识别到二维码，请重新上传';
        return;
      }

      this.applyQrContent(results[0].originalValue);
    } catch (err) {
      this.qrActionMessage = '本地图片二维码识别失败';
    }
  }

  async submitQrQuery(): Promise<void> {
    if (this.querying) {
      return;
    }

    this.qrQueryMessage = '';
    this.qrContent = DeviceService.normalizeQrContent(this.qrContent);
    this.querying = true;
    const response = await DeviceService.queryByQrContentRemoteFirst({
      qrContent: this.qrContent
    });
    this.querying = false;

    if (!response.success) {
      const error = response.error;
      if (error !== undefined && this.isQrValidationErrorCode(`${error.code}`)) {
        this.qrQueryMessage = this.formatQrValidationErrorMessage(`${error.code}`);
        this.qrContent = '';
      } else {
        this.qrQueryMessage = error ? error.message : '二维码查询失败';
      }
      return;
    }

    if (response.data !== undefined) {
      this.openDeviceArchiveDetail(response.data);
    }
  }

  applyQrContent(content: string): void {
    const qrContent = DeviceService.normalizeQrContent(content);
    if (qrContent.length === 0) {
      this.qrContent = '';
      this.qrActionMessage = '二维码内容为空';
      return;
    }

    const validation = DeviceService.validateQrQuery({
      qrContent: qrContent
    });
    if (!validation.valid) {
      this.qrContent = '';
      this.qrActionMessage = validation.message;
      return;
    }

    this.qrContent = qrContent;
    this.qrActionMessage = '';
    this.qrQueryMessage = '';
  }

  isQrValidationErrorCode(errorCode: string): boolean {
    return errorCode.startsWith('QR_');
  }

  formatQrValidationErrorMessage(errorCode: string): string {
    if (errorCode === 'QR_CODE_EXPIRED') {
      return '二维码已过期，请重新获取有效二维码';
    }

    if (errorCode === 'QR_DEVICE_NOT_FOUND') {
      return '二维码未关联设备档案';
    }

    return '二维码内容无效';
  }

  getQrPreview(): string {
    if (this.qrContent.length === 0) {
      return '-';
    }

    return this.getQrDeviceCodeDisplay();
  }

  getQrDeviceCodeDisplay(): string {
    const segments = this.qrContent.split(':');
    if (segments.length >= 3 && segments[0] === 'RDVP') {
      return DeviceService.normalizeDeviceCode(segments[2]);
    }

    return '待校验';
  }

  getQrSignatureFingerprint(): string {
    const segments = this.qrContent.split(':');
    if (segments.length < 5) {
      return '待校验';
    }

    const signature = segments[4].trim();
    if (signature.length <= 8) {
      return '****';
    }

    return `****${signature.substring(signature.length - 8)}`;
  }

  showQueryInfoDialog(): void {
    this.queryInfoDialogController.open();
  }

  openDeviceArchiveDetail(device: DeviceSummary): void {
    DeviceArchiveFlowStore.startFlow(device);

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveDetail' });
    } catch (err) {
      if (this.queryMode === DeviceQueryMode.Code) {
        this.codeQueryMessage = '设备档案详情不可用';
      } else {
        this.qrQueryMessage = '设备档案详情不可用';
      }
    }
  }

  backToWorkbench(): void {
    try {
      DeviceArchiveFlowStore.clearFlow();
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
