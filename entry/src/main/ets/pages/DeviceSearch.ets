import { DeviceService } from '../services/DeviceService';

@Entry
@Component
struct DeviceSearch {
  @State deviceCode: string = '';
  @State message: string = '';
  @State normalizedDeviceCode: string = '-';

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.Header()
        this.SearchPanel()
        this.ResultPanel()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: 18,
        right: 18,
        top: 22,
        bottom: 28
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  Header() {
    Row() {
      Column({ space: 4 }) {
        Text('设备编号查询')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)

        Text('设备档案')
          .fontSize(13)
          .fontColor('#6B7280')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('返回')
        .height(38)
        .fontSize(14)
        .fontColor('#374151')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#D1D5DB'
        })
        .onClick(() => {
          this.backToWorkbench();
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SearchPanel() {
    Column({ space: 14 }) {
      TextInput({
        placeholder: '设备编号',
        text: this.deviceCode
      })
        .height(48)
        .fontSize(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#D1D5DB'
        })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.message = '';
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
        })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor('#D9480F')
          .maxLines(2)
      }

      Button('查询')
        .height(48)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#2F6FED')
        .borderRadius(8)
        .onClick(() => {
          this.submitSearch();
        })
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({
      width: 1,
      color: '#E5E7EB'
    })
  }

  @Builder
  ResultPanel() {
    Column({ space: 12 }) {
      Text('查询状态')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.StatusRow('标准编号', this.normalizedDeviceCode, '#374151')
        this.StatusRow('服务状态', '未连接', '#D9480F')
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .border({
        width: 1,
        color: '#E5E7EB'
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  StatusRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#6B7280')
        .layoutWeight(1)
        .maxLines(1)

      Text(value)
        .fontSize(14)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(44)
    .padding({
      left: 14,
      right: 14
    })
    .width('100%')
  }

  submitSearch(): void {
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

  backToWorkbench(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
      } catch (innerErr) {
        this.message = '页面跳转失败';
      }
    }
  }
}

