import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceArchiveChangeRequestStatus } from '../../models/DeviceArchiveChangeModels';
import { DeviceStatus, DeviceSummary } from '../../models/DeviceModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceArchiveDeleteGuardService } from '../../services/DeviceArchiveDeleteGuardService';
import { DeviceArchiveLifecycleService } from '../../services/DeviceArchiveLifecycleService';
import { DeviceArchiveChangeService } from '../../services/DeviceArchiveChangeService';
import { DeviceService } from '../../services/DeviceService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const DEVICE_ARCHIVE_DELETE_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '删除申请',
    items: [
      {
        label: '适用场景',
        description: '仅在设备退役、撤场、误建档或档案确需撤销时提交删除申请，提交后进入管理员审核'
      },
      {
        label: '二次确认',
        description: '提交前需要校验当前账号密码和随机验证码，降低误操作和账号被冒用时的删除风险'
      },
      {
        label: '删除锁定',
        description: '同一设备连续五次密码错误后，十二小时内不可再次提交删除申请，其他业务操作不受影响'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveDelete {
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
  @State reason: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State requestStatus: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.Draft;
  @State submitting: boolean = false;
  @State confirmVisible: boolean = false;
  @State confirmPassword: string = '';
  @State confirmCaptcha: string = '';
  @State confirmCaptchaCode: string = DeviceArchiveDeleteGuardService.createCaptcha();
  @State confirmMessage: string = '';
  private deleteInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '设备档案删除说明',
      sections: DEVICE_ARCHIVE_DELETE_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceDelete)) {
      return;
    }

    this.loadArchiveContext();
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          this.PageTitleBar()

          Column({ space: 18 }) {
            this.ModeHeader()
            if (this.hasDevice) {
              this.ArchivePanel()
              this.DeleteForm()
              this.StatusPanel()
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

      if (this.confirmVisible) {
        this.ConfirmOverlay()
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    if (this.confirmVisible) {
      this.closeConfirmOverlay();
      return true;
    }

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
      .backgroundColor(AppColors.Surface)
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToDetail();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('设备档案删除')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.deleteInfoDialogController.open();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('提交设备档案删除审核申请')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 0, bottom: 2 })
  }

  @Builder
  ArchivePanel() {
    Column({ space: 10 }) {
      Text('目标档案')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '设备编号', value: this.device.deviceCode, tone: AppColors.TextSecondary, valueMaxLines: 2 })
        this.CardDivider()
        StatusInfoRow({ label: '设备名称', value: this.device.name, tone: AppColors.TextSecondary, valueMaxLines: 2 })
        this.CardDivider()
        StatusInfoRow({ label: '设备型号', value: this.device.model, tone: AppColors.TextSecondary, valueMaxLines: 2 })
        this.CardDivider()
        StatusInfoRow({ label: '设备位置', value: this.device.location.address, tone: AppColors.TextSecondary, valueMaxLines: 2 })
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  DeleteForm() {
    Column({ space: 16 }) {
      this.ReasonField()
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), $r('sys.symbol.trash'), this.canOpenConfirmation(), () => {
        this.prepareDeleteConfirmation();
      })
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
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('删除原因')

      TextArea({
        placeholder: '填写设备退役、撤场、误建档或其他删除依据',
        text: this.reason
      })
        .height(126)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(500)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.isSubmitted() && !this.submitting && !this.isDeleteLocked())
        .onChange((value: string) => {
          this.reason = value;
          this.message = '';
          this.messageTone = AppColors.Danger;
          if (!this.isSubmitted()) {
            this.requestStatus = DeviceArchiveChangeRequestStatus.Draft;
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('提交状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '申请状态',
          value: DeviceArchiveChangeService.formatRequestStatus(this.requestStatus),
          tone: this.getStatusTone(this.requestStatus)
        })
        this.CardDivider()
        StatusInfoRow({
          label: '删除锁定',
          value: DeviceArchiveDeleteGuardService.getDeleteLockMessage(this.device.deviceCode),
          tone: this.isDeleteLocked() ? AppColors.Danger : AppColors.Success,
          valueMaxLines: 2
        })
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
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ConfirmOverlay() {
    Column() {
      Column({ space: 16 }) {
        Row() {
          Text('确认删除申请')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .layoutWeight(1)
            .maxLines(1)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18)
              .fontColor([AppColors.TextPrimary])
          }
          .width(40)
          .height(40)
          .backgroundColor(AppColors.PageBackground)
          .onClick(() => {
            this.closeConfirmOverlay();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('删除档案属于敏感操作，请完成身份复核后提交审核申请。')
          .fontSize(14)
          .fontColor(AppColors.TextSecondary)
          .lineHeight(20)
          .width('100%')

        this.ConfirmPasswordField()
        this.ConfirmCaptchaField()
        this.ConfirmMessageText()

        Row({ space: 10 }) {
          Column() {
            this.ConfirmSecondaryButton('取消', () => {
              this.closeConfirmOverlay();
            })
          }
          .layoutWeight(1)

          Column() {
            this.ConfirmPrimaryButton(this.submitting ? '提交中' : '确认提交', () => {
              this.confirmAndSubmitDeleteRequest();
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('88%')
      .padding({
        left: 22,
        right: 22,
        top: 22,
        bottom: 22
      })
      .backgroundColor(AppColors.Surface)
      .borderRadius(28)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Scrim)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ConfirmPasswordField() {
    Column({ space: 8 }) {
      this.ConfirmFieldTitle('当前账号密码')

      TextInput({
        placeholder: '输入当前账号密码',
        text: this.confirmPassword
      })
        .type(InputType.Password)
        .height(54)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting)
        .onChange((value: string) => {
          this.confirmPassword = value;
          this.clearConfirmMessageWhenUserReenters(value);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ConfirmCaptchaField() {
    Column({ space: 8 }) {
      this.ConfirmFieldTitle('验证码')

      Row({ space: 10 }) {
        TextInput({
          placeholder: '输入验证码',
          text: this.confirmCaptcha
        })
          .height(54)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .layoutWeight(1)
          .enabled(!this.submitting)
          .onChange((value: string) => {
            this.confirmCaptcha = value;
            this.clearConfirmMessageWhenUserReenters(value);
          })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            Text(this.confirmCaptchaCode)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)

            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(16)
              .fontColor([AppColors.TextPrimary])
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .width('100%')
        }
        .width(116)
        .height(54)
        .backgroundColor(AppColors.PageBackground)
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting)
        .onClick(() => {
          this.refreshCaptcha();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ConfirmMessageText() {
    if (this.confirmMessage.length > 0) {
      Text(this.confirmMessage)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ConfirmFieldTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  FieldTitle(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .lineHeight(18)
        .maxLines(3)
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
          .fontColor([AppColors.Surface])

        Text(label)
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
    .backgroundColor(enabled ? AppColors.Danger : AppColors.Disabled)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  @Builder
  ConfirmPrimaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.submitting }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.Surface)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(this.submitting ? AppColors.Disabled : AppColors.Danger)
    .enabled(!this.submitting)
    .onClick(() => {
      action();
    })
  }

  @Builder
  ConfirmSecondaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.submitting }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(AppColors.FieldBackground)
    .border({ width: 1, color: AppColors.Border })
    .enabled(!this.submitting)
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({ left: 18, right: 18 })
  }

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      this.hasDevice = false;
      this.message = '未获取设备档案，请返回后重新查询';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.device = device;
    this.hasDevice = true;
    if (DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode)) {
      this.message = DeviceArchiveDeleteGuardService.getDeleteLockMessage(device.deviceCode);
      this.messageTone = AppColors.Danger;
    }
  }

  prepareDeleteConfirmation(): void {
    const validation = DeviceArchiveLifecycleService.validateDeleteRequestForm({
      device: this.device,
      reason: this.reason
    });
    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = AppColors.Danger;
      return;
    }

    if (this.isDeleteLocked()) {
      this.message = DeviceArchiveDeleteGuardService.getDeleteLockMessage(this.device.deviceCode);
      this.messageTone = AppColors.Danger;
      return;
    }

    this.confirmPassword = '';
    this.confirmCaptcha = '';
    this.confirmCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
    this.confirmMessage = '';
    this.confirmVisible = true;
  }

  async confirmAndSubmitDeleteRequest(): Promise<void> {
    if (this.submitting) {
      return;
    }

    this.submitting = true;
    const confirmation = await DeviceArchiveDeleteGuardService.verifyConfirmation({
      deviceCode: this.device.deviceCode,
      password: this.confirmPassword,
      captcha: this.confirmCaptcha,
      expectedCaptcha: this.confirmCaptchaCode
    });
    if (!confirmation.verified) {
      this.submitting = false;
      this.confirmMessage = confirmation.message;
      this.refreshCaptcha();
      return;
    }

    const response = await DeviceArchiveLifecycleService.submitDeleteRequestRemoteFirst({
      device: this.device,
      reason: this.reason
    });
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.confirmMessage = error ? error.message : '删除申请提交失败';
      this.refreshCaptcha();
      return;
    }

    DeviceArchiveFlowStore.markChangePending(response.data ? response.data.id : '');
    const pendingDevice = DeviceArchiveFlowStore.getCurrentDevice();
    if (pendingDevice !== undefined) {
      this.device = pendingDevice;
    }
    this.requestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
    this.confirmVisible = false;
    this.message = '删除申请已提交，等待管理员审核';
    this.messageTone = AppColors.Success;
  }

  refreshCaptcha(): void {
    this.confirmCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
    this.confirmCaptcha = '';
  }

  clearConfirmMessageWhenUserReenters(value: string): void {
    if (value.length > 0) {
      this.confirmMessage = '';
    }
  }

  closeConfirmOverlay(): void {
    if (this.submitting) {
      return;
    }

    this.confirmVisible = false;
    this.confirmPassword = '';
    this.confirmCaptcha = '';
    this.confirmMessage = '';
  }

  canOpenConfirmation(): boolean {
    return this.hasDevice && !this.submitting && !this.isSubmitted() && !this.isDeleteLocked();
  }

  isSubmitted(): boolean {
    return this.requestStatus === DeviceArchiveChangeRequestStatus.PendingReview;
  }

  isDeleteLocked(): boolean {
    return this.hasDevice && DeviceArchiveDeleteGuardService.isDeleteLocked(this.device.deviceCode);
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.isSubmitted()) {
      return '已提交';
    }

    return '提交申请';
  }

  getStatusTone(status: DeviceArchiveChangeRequestStatus): string {
    switch (status) {
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return AppColors.Warning;
      case DeviceArchiveChangeRequestStatus.Approved:
        return AppColors.Success;
      case DeviceArchiveChangeRequestStatus.Rejected:
        return AppColors.Danger;
      case DeviceArchiveChangeRequestStatus.Draft:
      default:
        return AppColors.TextSecondary;
    }
  }

  backToDetail(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveDetail' });
    } catch (err) {
      this.message = '页面跳转失败';
      this.messageTone = AppColors.Danger;
    }
  }
}
