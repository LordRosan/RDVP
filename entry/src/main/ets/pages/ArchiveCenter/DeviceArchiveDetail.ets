import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../../models/DeviceModels';
import { PermissionCode } from '../../models/PermissionModels';
import { DeviceArchiveDeleteGuardService } from '../../services/DeviceArchiveDeleteGuardService';
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
  @State detailMessage: string = '';
  @State detailMessageTone: string = AppColors.Danger;
  @State changeActionMessage: string = '';
  @State changeActionMessageTone: string = AppColors.Danger;
  @State deleteActionMessage: string = '';
  @State deleteActionMessageTone: string = AppColors.Danger;
  @State canChangeArchive: boolean = false;
  @State canDeleteArchive: boolean = false;
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
      this.detailMessage = '未获取设备档案，请重新查询';
      this.detailMessageTone = AppColors.Danger;
      this.changeActionMessage = '';
      this.deleteActionMessage = '';
      return;
    }

    this.device = device;
    this.hasDevice = true;
    this.canChangeArchive = SessionStore.hasPermission(PermissionCode.ArchiveChangeRequestCreate) &&
      !DeviceService.isArchiveChangeLocked(device);
    this.canDeleteArchive = SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete) &&
      !DeviceService.isArchiveChangeLocked(device) &&
      !DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode);
    this.detailMessage = '';
    this.detailMessageTone = AppColors.Danger;
    this.changeActionMessage = '';
    this.changeActionMessageTone = AppColors.Danger;
    if (DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode)) {
      this.deleteActionMessage = DeviceArchiveDeleteGuardService.getDeleteLockMessage(device.deviceCode);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    this.deleteActionMessage = '';
    this.deleteActionMessageTone = AppColors.Danger;
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
            if (this.shouldShowActionPanel()) {
              this.ActionPanel()
            }
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
    .backgroundColor(AppColors.PageBackground)
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
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('设备档案详情')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showDetailInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('查看设备档案与状态信息')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
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
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '设备编号',
          value: this.device.deviceCode,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备名称',
          value: this.device.name,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备型号',
          value: this.device.model,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '生产厂商',
          value: this.device.manufacturer,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备位置',
          value: this.device.location.address,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '最近核验',
          value: DeviceService.formatTimestampForDisplay(this.device.lastVerificationTime),
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
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
  StatusPanel() {
    Column({ space: 10 }) {
      Text('状态信息')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
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
          tone: DeviceService.isArchiveChangeLocked(this.device) ? AppColors.Danger : AppColors.Success,
          valueMaxLines: 2,
          verticalPadding: 12
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
  ActionPanel() {
    Column({ space: 12 }) {
      this.DetailMessageText()
      if (this.canViewChangeArchiveAction()) {
        this.ChangeActionMessageText()
        this.ChangeArchiveButton()
      }
      if (this.canViewDeleteArchiveAction()) {
        this.DeleteActionMessageText()
        this.DeleteArchiveButton()
      }
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
  EmptyPanel() {
    Column({ space: 12 }) {
      this.DetailMessageText()
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
  DetailMessageText() {
    if (this.detailMessage.length > 0) {
      Text(this.detailMessage)
        .fontSize(13)
        .fontColor(this.detailMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ChangeActionMessageText() {
    if (this.changeActionMessage.length > 0) {
      Text(this.changeActionMessage)
        .fontSize(13)
        .fontColor(this.changeActionMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  DeleteActionMessageText() {
    if (this.deleteActionMessage.length > 0) {
      Text(this.deleteActionMessage)
        .fontSize(13)
        .fontColor(this.deleteActionMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ChangeArchiveButton() {
    if (this.canViewChangeArchiveAction()) {
      Button({ type: ButtonType.Capsule, stateEffect: this.canChangeArchive }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.text_clipboard'))
            .fontSize(20)
            .fontColor([AppColors.Surface])

          Text('修改设备档案')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.Surface)
            .maxLines(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(54)
      .width('100%')
      .backgroundColor(this.canChangeArchive ? AppColors.Primary : AppColors.Disabled)
      .enabled(this.canChangeArchive)
      .onClick(() => {
        this.openChangePage();
      })
    }
  }

  @Builder
  DeleteArchiveButton() {
    if (this.canViewDeleteArchiveAction()) {
      Button({ type: ButtonType.Capsule, stateEffect: this.canDeleteArchive }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([AppColors.Surface])

          Text('删除设备档案')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.Surface)
            .maxLines(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(54)
      .width('100%')
      .backgroundColor(this.canDeleteArchive ? AppColors.Danger : AppColors.Disabled)
      .enabled(this.canDeleteArchive)
      .onClick(() => {
        this.openDeletePage();
      })
    }
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

  showDetailInfoDialog(): void {
    this.detailInfoDialogController.open();
  }

  shouldShowActionPanel(): boolean {
    return this.detailMessage.length > 0 || this.changeActionMessage.length > 0 ||
      this.deleteActionMessage.length > 0 || this.canViewChangeArchiveAction() || this.canViewDeleteArchiveAction();
  }

  canViewChangeArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveChangeRequestCreate);
  }

  canViewDeleteArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete);
  }

  openChangePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveChangeRequestCreate)) {
      this.changeActionMessage = '当前账号无权申请设备档案变更';
      this.changeActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceService.isArchiveChangeLocked(this.device)) {
      this.changeActionMessage = DeviceService.formatArchiveChangeLockReason(this.device);
      this.changeActionMessageTone = AppColors.Danger;
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveChange' });
    } catch (err) {
      this.changeActionMessage = '设备档案变更不可用';
      this.changeActionMessageTone = AppColors.Danger;
    }
  }

  openDeletePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete)) {
      this.deleteActionMessage = '当前账号无权申请删除设备档案';
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceArchiveDeleteGuardService.isDeleteLocked(this.device.deviceCode)) {
      this.deleteActionMessage = DeviceArchiveDeleteGuardService.getDeleteLockMessage(this.device.deviceCode);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceService.isArchiveChangeLocked(this.device)) {
      this.deleteActionMessage = DeviceService.formatArchiveChangeLockReason(this.device);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveDelete' });
    } catch (err) {
      this.deleteActionMessage = '设备档案删除不可用';
      this.deleteActionMessageTone = AppColors.Danger;
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

      router.replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
