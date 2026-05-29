import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit';
import { DeviceQueryMode } from '../models/DeviceModels';
import { DeviceService } from '../services/DeviceService';

@Entry
@Component
struct DeviceQuery {
  @State queryMode: DeviceQueryMode = DeviceQueryMode.Code;
  @State deviceCode: string = '';
  @State qrContent: string = '';
  @State message: string = '';
  @State normalizedDeviceCode: string = '-';

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
    .backgroundColor('#F2F5F7')
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
          .fontColor(['#111827'])
      }
      .width(44)
      .height(44)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
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
    .backgroundColor('#F2F5F7')
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.getModeTitle())
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getModeSubtitle())
          .fontSize(15)
          .fontColor('#6B7280')
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
          .fontColor(['#111827'])
      } else {
        SymbolGlyph($r('sys.symbol.character_textbox'))
          .fontSize(31)
          .fontColor(['#111827'])
      }
    }
    .width(58)
    .height(58)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#E5E7EB'
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
      Text('设备编号')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      TextInput({
        placeholder: '输入设备编号',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor('#FBFCFE')
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.message = '';
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
        })

      this.MessageText()
      this.ActionButton('查询', $r('sys.symbol.magnifyingglass'), () => {
        this.submitDeviceCodeQuery();
      })
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QrQueryPanel() {
    Column({ space: 14 }) {
      Stack() {
        if (this.qrContent.length > 0) {
          Text(this.qrContent)
            .fontSize(14)
            .fontColor('#111827')
            .lineHeight(21)
            .maxLines(10)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding(18)
            .width('100%')
            .height('100%')
        } else {
          Column({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.qrcode'))
              .fontSize(56)
              .fontColor(['#C4CAD3'])

            Text('未获取二维码内容')
              .fontSize(15)
              .fontColor('#9CA3AF')
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
      .backgroundColor('#F7F9FC')
      .borderRadius(22)
      .border({
        width: 1,
        color: '#D6DAE1'
      })

      this.MessageText()

      Row({ space: 10 }) {
        Column() {
          this.ActionButton('扫描', $r('sys.symbol.circle_viewfinder'), () => {
            this.scanQrCode();
          })
        }
        .layoutWeight(1)

        Column() {
          this.ActionButton('上传', $r('sys.symbol.picture'), () => {
            this.uploadQrImage();
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.ActionButton('查询', $r('sys.symbol.magnifyingglass'), () => {
        this.submitQrQuery();
      })
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor('#D9480F')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor(['#FFFFFF'])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor('#2F6FED')
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
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.StatusRow('查询方式', this.getQueryMethodText(), '#374151')
        this.CardDivider()
        this.StatusRow(this.queryMode === DeviceQueryMode.Code ? '标准编号' : '二维码内容',
          this.queryMode === DeviceQueryMode.Code ? this.normalizedDeviceCode : this.getQrPreview(), '#374151')
        this.CardDivider()
        this.StatusRow('服务状态', '未连接', '#D9480F')
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor('#E5E7EB')
      .margin({
        left: 18,
        right: 18
      })
  }

  @Builder
  StatusRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#111827')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(15)
        .fontColor(tone)
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

  switchQueryMode(): void {
    this.message = '';
    this.queryMode = this.queryMode === DeviceQueryMode.Code ? DeviceQueryMode.Qr : DeviceQueryMode.Code;
  }

  getModeTitle(): string {
    return this.queryMode === DeviceQueryMode.Code ? '设备编号查询' : '二维码查询';
  }

  getModeSubtitle(): string {
    return this.queryMode === DeviceQueryMode.Code ? '输入设备编号定位设备档案' : '扫描或上传二维码定位设备档案';
  }

  getQueryMethodText(): string {
    return this.queryMode === DeviceQueryMode.Code ? '设备编号' : '二维码';
  }

  submitDeviceCodeQuery(): void {
    const response = DeviceService.queryByCode({
      deviceCode: this.deviceCode
    });

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '设备查询失败';
    }
  }

  async scanQrCode(): Promise<void> {
    this.message = '';
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.message = '无法获取页面上下文';
      return;
    }

    try {
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableAlbum: false
      });
      this.applyQrContent(result.originalValue);
    } catch (err) {
      this.message = '扫码取消或失败';
    }
  }

  async uploadQrImage(): Promise<void> {
    this.message = '';

    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      if (selection.photoUris.length === 0) {
        this.message = '未选择图片';
        return;
      }

      const results = await detectBarcode.decode({
        uri: selection.photoUris[0]
      }, {
        scanTypes: [scanCore.ScanType.QR_CODE]
      });

      if (results.length === 0) {
        this.message = '未识别到二维码，请重新上传';
        return;
      }

      this.applyQrContent(results[0].originalValue);
    } catch (err) {
      this.message = '本地图片二维码识别失败';
    }
  }

  submitQrQuery(): void {
    this.qrContent = DeviceService.normalizeQrContent(this.qrContent);
    const response = DeviceService.queryByQrContent({
      qrContent: this.qrContent
    });

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '二维码查询失败';
    }
  }

  applyQrContent(content: string): void {
    const qrContent = DeviceService.normalizeQrContent(content);
    if (qrContent.length === 0) {
      this.message = '二维码内容为空';
      return;
    }

    this.qrContent = qrContent;
    this.message = '';
  }

  getQrPreview(): string {
    if (this.qrContent.length === 0) {
      return '-';
    }

    if (this.qrContent.length > 24) {
      return `${this.qrContent.substring(0, 24)}...`;
    }

    return this.qrContent;
  }

  backToWorkbench(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Index' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
