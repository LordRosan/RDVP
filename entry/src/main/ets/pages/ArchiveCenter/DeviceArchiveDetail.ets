import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../../models/DeviceModels';
import { PermissionCode } from '../../models/PermissionModels';
import { DeviceArchiveLifecycleService } from '../../services/DeviceArchiveLifecycleService';
import { DeviceService } from '../../services/DeviceService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

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
  @State messageTone: string = '#D9480F';
  @State canChangeArchive: boolean = false;
  @State canDeleteArchive: boolean = false;
  @State deleteReason: string = '';
  @State showDeleteForm: boolean = false;
  @State deleting: boolean = false;
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
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceRead)) {
      return;
    }

    this.loadArchiveContext();
  }

  onPageShow(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceRead)) {
      return;
    }

    this.loadArchiveContext();
  }

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      this.hasDevice = false;
      this.canChangeArchive = false;
      this.canDeleteArchive = false;
      this.message = '未获取设备档案，请重新查询';
      this.messageTone = '#D9480F';
      return;
    }

    this.device = device;
    this.hasDevice = true;
    this.canChangeArchive = SessionStore.hasPermission(PermissionCode.ArchiveChangeRequestCreate) &&
      !DeviceService.isArchiveChangeLocked(device);
    this.canDeleteArchive = SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete) &&
      !DeviceService.isArchiveChangeLocked(device);
    this.message = '';
    this.messageTone = '#D9480F';
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
        StatusInfoRow({
          label: '设备编号',
          value: this.device.deviceCode,
          tone: '#374151',
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备名称',
          value: this.device.name,
          tone: '#374151',
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备型号',
          value: this.device.model,
          tone: '#374151',
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '生产厂商',
          value: this.device.manufacturer,
          tone: '#374151',
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备位置',
          value: this.device.location.address,
          tone: '#374151',
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '最近核验',
          value: this.device.lastVerificationTime ? this.device.lastVerificationTime : '-',
          tone: '#374151',
          valueMaxLines: 2,
          verticalPadding: 12
        })
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
        StatusInfoRow({
          label: '设备状态',
          value: DeviceService.formatDeviceStatus(this.device.status),
          tone: DeviceService.getDeviceStatusTone(this.device.status),
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '变更状态',
          value: DeviceService.formatArchiveChangeLockReason(this.device),
          tone: DeviceService.isArchiveChangeLocked(this.device) ? '#D9480F' : '#087F5B',
          valueMaxLines: 2,
          verticalPadding: 12
        })
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
      this.ChangeArchiveButton()
      this.DeleteArchiveSection()
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
        .fontColor(this.messageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ChangeArchiveButton() {
    Button({ type: ButtonType.Capsule, stateEffect: this.canChangeArchive }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.text_clipboard'))
          .fontSize(20)
          .fontColor(['#FFFFFF'])

        Text('修改设备档案')
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
    .backgroundColor(this.canChangeArchive ? '#2F6FED' : '#AEB6C2')
    .enabled(this.canChangeArchive)
    .onClick(() => {
      this.openChangePage();
    })
  }

  @Builder
  DeleteArchiveSection() {
    if (SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete)) {
      if (this.showDeleteForm) {
        Column({ space: 12 }) {
          this.FieldTitle('删除原因')
          TextArea({
            placeholder: '填写设备退役、撤场、误建档或其他删除依据',
            text: this.deleteReason
          })
            .height(104)
            .width('100%')
            .fontSize(15)
            .lineHeight(22)
            .maxLength(500)
            .backgroundColor('#F7F9FC')
            .borderRadius(18)
            .padding({
              left: 14,
              right: 14,
              top: 12,
              bottom: 12
            })
            .border({ width: 1, color: '#D6DAE1' })
            .enabled(!this.deleting && this.canDeleteArchive)
            .onChange((value: string) => {
              this.deleteReason = value;
              this.message = '';
              this.messageTone = '#D9480F';
            })

          Row({ space: 10 }) {
            Column() {
              this.ActionButton(this.deleting ? '提交中' : '提交删除申请', $r('sys.symbol.trash'),
                this.canDeleteArchive && !this.deleting, () => {
                  this.submitDeleteRequest();
                })
            }
            .layoutWeight(1)

            Column() {
              this.SecondaryButton('取消', () => {
                this.showDeleteForm = false;
                this.deleteReason = '';
                this.message = '';
                this.messageTone = '#D9480F';
              })
            }
            .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        this.ActionButton('申请删除档案', $r('sys.symbol.trash'), this.canDeleteArchive, () => {
          if (!this.canDeleteArchive) {
            this.message = DeviceService.formatArchiveChangeLockReason(this.device);
            this.messageTone = '#D9480F';
            return;
          }

          this.showDeleteForm = true;
        })
      }
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
  SecondaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(label)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .maxLines(1)
    }
    .height(54)
    .width('100%')
    .backgroundColor('#F7F9FC')
    .border({ width: 1, color: '#D6DAE1' })
    .onClick(() => {
      action();
    })
  }

  @Builder
  FieldTitle(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor('#111827')
      .maxLines(1)
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

  showDetailInfoDialog(): void {
    this.detailInfoDialogController.open();
  }

  openChangePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveChangeRequestCreate)) {
      this.message = '当前账号无权申请设备档案变更';
      this.messageTone = '#D9480F';
      return;
    }

    if (DeviceService.isArchiveChangeLocked(this.device)) {
      this.message = DeviceService.formatArchiveChangeLockReason(this.device);
      this.messageTone = '#D9480F';
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveChange' });
    } catch (err) {
      this.message = '设备档案变更不可用';
      this.messageTone = '#D9480F';
    }
  }

  async submitDeleteRequest(): Promise<void> {
    if (this.deleting || !this.canDeleteArchive) {
      return;
    }

    const validation = DeviceArchiveLifecycleService.validateDeleteRequestForm({
      device: this.device,
      reason: this.deleteReason
    });
    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = '#D9480F';
      return;
    }

    this.deleting = true;
    const response = await DeviceArchiveLifecycleService.submitDeleteRequestRemoteFirst({
      device: this.device,
      reason: this.deleteReason
    });
    this.deleting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '删除申请提交失败';
      this.messageTone = '#D9480F';
      return;
    }

    DeviceArchiveFlowStore.markChangePending(response.data ? response.data.id : '');
    const pendingDevice = DeviceArchiveFlowStore.getCurrentDevice();
    if (pendingDevice !== undefined) {
      this.device = pendingDevice;
    }
    this.canChangeArchive = false;
    this.canDeleteArchive = false;
    this.showDeleteForm = false;
    this.message = '删除申请已提交，等待管理员审核';
    this.messageTone = '#087F5B';
  }

  returnToQuery(): void {
    try {
      DeviceArchiveFlowStore.clearFlow();
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
    } catch (err) {
      this.message = '页面跳转失败';
      this.messageTone = '#D9480F';
    }
  }
}
