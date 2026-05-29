import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import { DeviceStatus, DeviceSummary } from '../models/DeviceModels';
import { DeviceService } from '../services/DeviceService';
import { DeviceArchiveFlowStore } from '../stores/DeviceArchiveFlowStore';
import { AuthGuard } from '../utils/AuthGuard';

const DEVICE_ARCHIVE_DETAIL_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '设备档案详情',
    items: [
      {
        label: '档案信息',
        description: '展示设备编号、名称、型号、厂商、位置和最近核验时间，作为后续业务操作依据'
      },
      {
        label: '状态信息',
        description: '展示设备运行、维修、复检和档案变更状态，帮助判断当前可执行的操作'
      },
      {
        label: '变更限制',
        description: '存在待审核变更或处于冻结期时，前端会提示不可修改，最终限制必须由后端强制校验'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveDetail {
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
  @State message: string = '';
  private detailInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '设备档案详情说明',
      sections: DEVICE_ARCHIVE_DETAIL_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requireAuthenticated(this.getUIContext())) {
      return;
    }

    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      this.hasDevice = false;
      this.message = '未获取设备档案，请重新查询';
      return;
    }

    this.device = device;
    this.hasDevice = true;
    this.message = '';
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          if (this.hasDevice) {
            this.ArchivePanel()
            this.StatusPanel()
            this.ActionPanel()
          } else {
            this.EmptyPanel()
          }
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
    this.returnToQuery();
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
        this.returnToQuery();
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
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('设备档案详情')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showDetailInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('查看设备档案与状态信息')
        .fontSize(15)
        .fontColor('#6B7280')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: 0,
      bottom: 2
    })
  }

  @Builder
  ArchivePanel() {
    Column({ space: 10 }) {
      Text('档案信息')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.StatusRow('设备编号', this.device.deviceCode, '#374151')
        this.CardDivider()
        this.StatusRow('设备名称', this.device.name, '#374151')
        this.CardDivider()
        this.StatusRow('设备型号', this.device.model, '#374151')
        this.CardDivider()
        this.StatusRow('生产厂商', this.device.manufacturer, '#374151')
        this.CardDivider()
        this.StatusRow('设备位置', this.device.location.address, '#374151')
        this.CardDivider()
        this.StatusRow('最近核验', this.device.lastVerificationTime ? this.device.lastVerificationTime : '-', '#374151')
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('状态信息')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.StatusRow('设备状态', DeviceService.formatDeviceStatus(this.device.status),
          DeviceService.getDeviceStatusTone(this.device.status))
        this.CardDivider()
        this.StatusRow('变更状态', DeviceService.formatArchiveChangeLockReason(this.device),
          DeviceService.isArchiveChangeLocked(this.device) ? '#D9480F' : '#087F5B')
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  ActionPanel() {
    Column({ space: 12 }) {
      this.MessageText()
      this.ActionButton('修改设备档案', $r('sys.symbol.text_clipboard'), !DeviceService.isArchiveChangeLocked(this.device), () => {
        this.openChangePage();
      })
      this.ActionButton('返回设备查询', $r('sys.symbol.magnifyingglass'), true, () => {
        this.returnToQuery();
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
  EmptyPanel() {
    Column({ space: 12 }) {
      this.MessageText()
      this.ActionButton('返回设备查询', $r('sys.symbol.magnifyingglass'), true, () => {
        this.returnToQuery();
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
  InfoButton(action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor(['#111827'])
    }
    .width(28)
    .height(28)
    .backgroundColor('#00000000')
    .onClick(() => {
      action();
    })
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
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
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
    .backgroundColor(enabled ? '#2F6FED' : '#AEB6C2')
    .enabled(enabled)
    .onClick(() => {
      action();
    })
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
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .constraintSize({ minHeight: 54 })
    .padding({
      left: 18,
      right: 18,
      top: 12,
      bottom: 12
    })
    .width('100%')
  }

  showDetailInfoDialog(): void {
    this.detailInfoDialogController.open();
  }

  openChangePage(): void {
    if (DeviceService.isArchiveChangeLocked(this.device)) {
      this.message = DeviceService.formatArchiveChangeLockReason(this.device);
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DeviceArchiveChange' });
    } catch (err) {
      this.message = '设备档案变更不可用';
    }
  }

  returnToQuery(): void {
    try {
      DeviceArchiveFlowStore.clearFlow();
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/DeviceArchiveQuery' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
