import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { DeviceArchiveInfoCard } from '../../components/DeviceArchiveInfoCard';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { DeviceArchiveRequestStatus } from '../../models/archive/DeviceArchiveRequestModels';
import { DeviceStatus, DeviceSummary } from '../../models/archive/DeviceModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { DeviceArchiveDeleteGuardService } from '../../services/archive/DeviceArchiveDeleteGuardService';
import { DeviceArchiveRequestService } from '../../services/archive/DeviceArchiveRequestService';
import { DeviceService } from '../../services/archive/DeviceService';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { AuthService } from '../../services/identity/AuthService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

@Entry
@Component
struct DeviceArchiveDelete {
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
  @State reason: string = '';
  @State deleteTime: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State requestStatus: DeviceArchiveRequestStatus = DeviceArchiveRequestStatus.Draft;
  @State submitting: boolean = false;
  @State password: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(),
      PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit)) {
      return;
    }

    this.loadArchiveContext();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          if (this.hasDevice) {
            this.DeleteForm()
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
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToDetail();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToDetail();
      }
    })
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('删除设备档案')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Device Archive Delete')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 6 })
  }

  @Builder
  DeleteForm() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '删除信息',
        subtitle: ''
      })

      DeviceArchiveInfoCard({
        device: this.device
      })

      Column({ space: 16 }) {
        this.DeleteTimeField()
        this.ReasonField()
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
      .border({ width: 1, color: AppColors.Divider })
      .alignItems(HorizontalAlign.Start)

      this.PasswordSection()
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), this.getSubmitIcon(), this.canSubmitDelete(), () => {
        this.submitDeleteRequest();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PasswordSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '密码',
        subtitle: ''
      })

      TextInput({
        placeholder: '请输入密码',
        text: this.password
      })
        .type(InputType.Password)
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting && !this.isSubmitted() && !this.isDeleteLocked())
        .onChange((value: string) => {
          if (this.submitting || this.isSubmitted() || this.isDeleteLocked()) {
            return;
          }

          this.password = value;
          this.message = '';
          this.messageTone = UiFeedbackTone.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeleteTimeField() {
    Column({ space: 10 }) {
      this.FieldTitle('删除时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.deleteTime.length > 0 ? this.deleteTime : '请选择删除时间')
          .fontSize(16)
          .fontColor(this.deleteTime.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor([AppColors.TextSecondary])
      }
      .height(56)
      .width('100%')
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .border({ width: 1, color: AppColors.Border })
      .onClick(() => {
        if (this.isSubmitted() || this.submitting || this.isDeleteLocked()) {
          return;
        }

        this.showDeleteTimePicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('删除原因')

      TextArea({
        placeholder: '请输入删除原因',
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
          this.messageTone = UiFeedbackTone.Danger;
          if (!this.isSubmitted()) {
            this.requestStatus = DeviceArchiveRequestStatus.Draft;
          }
        })
    }
    .width('100%')
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
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
    .alignItems(HorizontalAlign.Start)
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
      InlineMessageSurface({
        message: this.message,
        tone: this.messageTone
      })
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
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
    .backgroundColor(enabled ? AppColors.Danger : AppColors.Disabled)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      const lastCode = DeviceArchiveFlowStore.getLastDeviceCode();
      if (lastCode.length > 0) {
        this.reloadDeviceByCode(lastCode);
        return;
      }

      this.hasDevice = false;
      this.message = UiFeedbackService.operationUnavailable('查询');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.device = device;
    this.hasDevice = true;
    if (DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode)) {
      this.message = DeviceArchiveDeleteGuardService.getDeleteLockMessage(device.deviceCode);
      this.messageTone = UiFeedbackTone.Danger;
    }
  }

  async submitDeleteRequest(): Promise<void> {
    if (this.submitting) {
      return;
    }

    const validation = DeviceArchiveRequestService.validateDeleteRequestForm({
      device: this.device,
      reason: this.reason,
      initiatedAt: this.deleteTime
    });
    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    if (this.isDeleteLocked()) {
      this.message = DeviceArchiveDeleteGuardService.getDeleteLockMessage(this.device.deviceCode);
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    if (this.password.length === 0) {
      this.message = UiFeedbackService.requiredInput('密码');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.submitting = true;
    try {
      const verified = await this.verifyPasswordForSubmit(this.password);
      if (!verified) {
        return;
      }

      const response = await DeviceArchiveRequestService.submitDeleteRequestRemoteFirst({
        device: this.device,
        reason: this.reason,
        initiatedAt: this.deleteTime
      });

      if (!response.success) {
        this.message = UiFeedbackService.operationUnavailable('删除');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      this.requestStatus =
        response.data === undefined ? DeviceArchiveRequestStatus.PendingReview : response.data.status;
      DeviceArchiveFlowStore.markArchiveRequestPending(response.data ? response.data.id : '', undefined,
        this.requestStatus);
      const pendingDevice = DeviceArchiveFlowStore.getCurrentDevice();
      if (pendingDevice !== undefined) {
        this.device = pendingDevice;
      }
      this.password = '';
      this.message = UiFeedbackService.operationSuccess('提交');
      this.messageTone = UiFeedbackTone.Success;
    } finally {
      this.submitting = false;
    }
  }

  async verifyPasswordForSubmit(password: string): Promise<boolean> {
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(password);
    if (response.success && response.data === true) {
      DeviceArchiveDeleteGuardService.clearDeleteLock(this.device.deviceCode);
      return true;
    }

    if (DeviceArchiveDeleteGuardService.isPasswordIncorrectResponse(response)) {
      const result = DeviceArchiveDeleteGuardService.registerDeletePasswordFailure(this.device.deviceCode);
      this.message = result.lockedUntil === undefined ? UiFeedbackService.incorrect('密码') : UiFeedbackService.sanitize(result.message);
      this.messageTone = UiFeedbackTone.Danger;
      return false;
    }

    this.message = UiFeedbackService.passwordVerificationError(response.error, '删除');
    this.messageTone = UiFeedbackTone.Danger;
    return false;
  }

  canSubmitDelete(): boolean {
    return this.hasDevice && !this.submitting && !this.isSubmitted() && !this.isDeleteLocked();
  }

  isSubmitted(): boolean {
    return this.requestStatus === DeviceArchiveRequestStatus.PendingReview;
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

  getSubmitIcon(): Resource {
    return $r('sys.symbol.checkmark_circle');
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
      try {
        this.getUIContext().getPromptAction().showToast({ message: UiFeedbackService.operationUnavailable('页面跳转') });
      } catch (toastErr) {
      }
    }
  }

  async reloadDeviceByCode(deviceCode: string): Promise<void> {
    this.message = UiFeedbackService.sanitize('正在重新获取设备档案');
    this.messageTone = UiFeedbackTone.Info;
    const response = await DeviceService.queryByCodeRemoteFirst({
      deviceCode
    });
    if (response.success && response.data !== undefined) {
      DeviceArchiveFlowStore.startFlow(response.data);
      this.loadArchiveContext();
    } else {
      this.hasDevice = false;
      this.message = UiFeedbackService.operationUnavailable('查询');
      this.messageTone = UiFeedbackTone.Danger;
    }
  }

  showDeleteTimePicker(): void {
    if (this.isSubmitted() || this.submitting || this.isDeleteLocked()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.deleteTime),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.deleteTime = this.formatDateTime(value);
        this.message = '';
        this.messageTone = UiFeedbackTone.Danger;
        if (!this.isSubmitted()) {
          this.requestStatus = DeviceArchiveRequestStatus.Draft;
        }
      }
    });
  }

  resolveSelectedDate(value: string): Date {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return new Date();
    }

    const segments = trimmed.split(' ');
    if (segments.length !== 2) {
      return new Date();
    }

    const dateSegments = segments[0].split('-');
    const timeSegments = segments[1].split(':');
    if (dateSegments.length !== 3 || timeSegments.length < 2) {
      return new Date();
    }

    const year = Number(dateSegments[0]);
    const month = Number(dateSegments[1]);
    const day = Number(dateSegments[2]);
    const hour = Number(timeSegments[0]);
    const minute = Number(timeSegments[1]);
    if (year !== year || month !== month || day !== day || hour !== hour || minute !== minute) {
      return new Date();
    }

    return new Date(year, month - 1, day, hour, minute);
  }

  formatDateTime(value: Date): string {
    return `${value.getFullYear()}-${this.pad2(value.getMonth() + 1)}-${this.pad2(value.getDate())} ${this.pad2(
      value.getHours())}:${this.pad2(value.getMinutes())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
