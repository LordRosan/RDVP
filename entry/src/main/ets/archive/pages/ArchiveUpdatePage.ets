import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import {
  ArchiveUpdateBaseline,
  ArchiveUpdateDraft,
  ArchiveUpdateRequestForm,
  ArchiveRequestStatus
} from '../models/ArchiveRequestModels';
import { PermissionCode } from '../../user/models/PermissionModels';
import { ArchiveUpdateService } from '../services/ArchiveUpdateService';
import { DeviceService } from '../services/DeviceService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { AuthService } from '../../user/services/AuthService';
import { ArchiveFlowStore } from '../stores/ArchiveFlowStore';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';

@Entry
@Component
struct ArchiveUpdatePage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State deviceName: string = '';
  @State model: string = '';
  @State manufacturer: string = '';
  @State locationAddress: string = '';
  @State reason: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State normalizedDeviceCode: string = '-';
  @State updatedFieldCount: number = 0;
  @State initiatedAt: string = '';
  @State password: string = '';
  @State requestStatus: ArchiveRequestStatus = ArchiveRequestStatus.Draft;
  @State hasDevice: boolean = false;
  @State submitting: boolean = false;
  private currentDeviceId: string = '';
  private baseline?: ArchiveUpdateBaseline = undefined;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(),
      PermissionCode.ArchiveCenterArchiveUpdateRequestSubmit)) {
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
          this.UpdateForm()
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
      Text('修改档案')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Device Archive Update')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: 12,
      bottom: 6
    })
  }

  @Builder
  UpdateForm() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '修改信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.DeviceCodeField()
        this.DeviceNameField()
        this.DeviceModelField()
        this.ManufacturerField()
        this.LocationAddressField()
        this.InitiatedAtField()
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
      this.ActionButton(this.getSubmitButtonLabel(), this.getSubmitIcon(),
        this.hasDevice && !this.submitting && !this.isUpdateSubmitted(), () => {
          this.submitUpdateRequest();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceCodeField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备编号')

      TextInput({
        placeholder: '设备编号',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .fontColor(AppColors.TextSecondary)
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .enabled(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceNameField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备名称')

      if (this.submitting || this.isUpdateSubmitted()) {
        Text(this.deviceName)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的设备名称',
          text: this.deviceName
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.deviceName = value;
            this.message = '';
            this.updateFieldCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceModelField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备型号')

      if (this.submitting || this.isUpdateSubmitted()) {
        Text(this.model)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的设备型号',
          text: this.model
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.model = value;
            this.message = '';
            this.updateFieldCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ManufacturerField() {
    Column({ space: 10 }) {
      this.FieldTitle('生产厂商')

      if (this.submitting || this.isUpdateSubmitted()) {
        Text(this.manufacturer)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的生产厂商',
          text: this.manufacturer
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.manufacturer = value;
            this.message = '';
            this.updateFieldCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LocationAddressField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备位置')

      if (this.submitting || this.isUpdateSubmitted()) {
        Text(this.locationAddress)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的设备位置',
          text: this.locationAddress
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.locationAddress = value;
            this.message = '';
            this.updateFieldCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InitiatedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('修改时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.initiatedAt.length > 0 ? this.initiatedAt : '请选择修改时间')
          .fontSize(16)
          .fontColor(this.initiatedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
      .padding({
        left: 16,
        right: 16
      })
      .border({
        width: 1,
        color: AppColors.Border
      })
      .onClick(() => {
        if (this.submitting || this.isUpdateSubmitted()) {
          return;
        }

        this.showInitiatedAtPicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('修改原因')

      TextArea({
        placeholder: '请输入修改原因',
        text: this.reason
      })
        .height(118)
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
        .border({
          width: 1,
          color: AppColors.Border
        })
        .enabled(!this.submitting && !this.isUpdateSubmitted())
        .onChange((value: string) => {
          this.reason = value;
          this.message = '';
          this.saveDraft();
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
        .enabled(!this.submitting && !this.isUpdateSubmitted())
        .onChange((value: string) => {
          if (this.submitting || this.isUpdateSubmitted()) {
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
    .backgroundColor(enabled ? AppColors.Primary : AppColors.Disabled)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  async submitUpdateRequest(): Promise<void> {
    if (this.submitting) {
      return;
    }

    const form = this.buildForm();
    const validation = ArchiveUpdateService.validateUpdateRequestForm(form);
    this.normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(this.deviceCode);
    this.updatedFieldCount = validation.fieldCount !== undefined ?
      validation.fieldCount : ArchiveUpdateService.countUpdatedFields(form);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!validation.valid) {
      this.message = validation.message;
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

      const response = await ArchiveUpdateService.submitUpdateRequestRemoteFirst(form);
      if (!response.success) {
        this.message = UiFeedbackService.operationUnavailable('修改');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      const submittedDraft = this.buildDraft();
      this.requestStatus =
        response.data === undefined ? ArchiveRequestStatus.PendingReview : response.data.status;
      ArchiveFlowStore.markArchiveRequestPending(response.data ? response.data.id : '', submittedDraft,
        this.requestStatus);
      this.applyDraft(submittedDraft);
      this.updatedFieldCount = ArchiveUpdateService.countUpdatedFields(this.buildForm());
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
      return true;
    }

    this.message = UiFeedbackService.passwordVerificationError(response.error, '修改');
    this.messageTone = UiFeedbackTone.Danger;
    return false;
  }

  buildForm(): ArchiveUpdateRequestForm {
    return {
      deviceId: this.currentDeviceId,
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason,
      initiatedAt: this.initiatedAt,
      baseline: this.baseline
    };
  }

  updateFieldCount(): void {
    this.updatedFieldCount = ArchiveUpdateService.countUpdatedFields(this.buildForm());
    if (!this.isUpdateSubmitted()) {
      this.requestStatus = ArchiveRequestStatus.Draft;
    }
  }

  getStatusTone(status: ArchiveRequestStatus): string {
    switch (status) {
      case ArchiveRequestStatus.PendingReview:
        return AppColors.Warning;
      case ArchiveRequestStatus.Approved:
        return AppColors.Success;
      case ArchiveRequestStatus.Rejected:
        return AppColors.Danger;
      case ArchiveRequestStatus.Withdrawn:
        return AppColors.TextSecondary;
      case ArchiveRequestStatus.Draft:
      default:
        return AppColors.TextSecondary;
    }
  }

  isUpdateSubmitted(): boolean {
    return this.requestStatus === ArchiveRequestStatus.PendingReview;
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.isUpdateSubmitted()) {
      return '已提交';
    }

    return '提交申请';
  }

  getSubmitIcon(): Resource {
    return $r('sys.symbol.checkmark_circle');
  }

  loadArchiveContext(): void {
    const device = ArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      const lastCode = ArchiveFlowStore.getLastDeviceCode();
      if (lastCode.length > 0) {
        this.reloadDeviceByCode(lastCode);
        return;
      }

      this.hasDevice = false;
      this.message = UiFeedbackService.operationUnavailable('查询');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.hasDevice = true;
    this.currentDeviceId = device.id;
    this.baseline = {
      deviceName: device.name,
      model: device.model,
      manufacturer: device.manufacturer,
      locationAddress: device.location.address
    };

    const pendingDraft = ArchiveFlowStore.getPendingDraft();
    if (pendingDraft !== undefined && pendingDraft.deviceCode === device.deviceCode) {
      this.applyDraft(pendingDraft);
      this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
      this.updatedFieldCount = ArchiveUpdateService.countUpdatedFields(this.buildForm());
      this.requestStatus = ArchiveFlowStore.getPendingRequestStatus();
      this.message = UiFeedbackService.operationSuccess('提交');
      this.messageTone = UiFeedbackTone.Success;
      return;
    }

    const draft = ArchiveFlowStore.getDraft();
    if (draft !== undefined && draft.deviceCode === device.deviceCode) {
      this.applyDraft(draft);
    } else {
      this.deviceCode = device.deviceCode;
      this.deviceName = device.name;
      this.model = device.model;
      this.manufacturer = device.manufacturer;
      this.locationAddress = device.location.address;
      this.reason = '';
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    this.updateFieldCount();
  }

  applyDraft(draft: ArchiveUpdateDraft): void {
    this.deviceCode = draft.deviceCode;
    this.deviceName = draft.deviceName;
    this.model = draft.model;
    this.manufacturer = draft.manufacturer;
    this.locationAddress = draft.locationAddress;
    this.reason = draft.reason;
    if (draft.initiatedAt !== undefined) {
      this.initiatedAt = draft.initiatedAt;
    }
  }

  saveDraft(): void {
    if (!this.hasDevice) {
      return;
    }

    ArchiveFlowStore.saveDraft(this.buildDraft());
  }

  buildDraft(): ArchiveUpdateDraft {
    return {
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason,
      initiatedAt: this.initiatedAt
    };
  }

  backToDetail(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'archive/pages/ArchiveDetailPage', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }

  async reloadDeviceByCode(deviceCode: string): Promise<void> {
    this.message = UiFeedbackService.sanitize('正在重新获取档案');
    this.messageTone = UiFeedbackTone.Info;
    const response = await DeviceService.queryByCodeRemoteFirst({
      deviceCode
    });
    if (response.success && response.data !== undefined) {
      ArchiveFlowStore.startFlow(response.data);
      this.loadArchiveContext();
    } else {
      this.hasDevice = false;
      this.message = UiFeedbackService.operationUnavailable('查询');
      this.messageTone = UiFeedbackTone.Danger;
    }
  }

  showInitiatedAtPicker(): void {
    if (this.submitting || this.isUpdateSubmitted()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.initiatedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.initiatedAt = this.formatDateTime(value);
        this.message = '';
        this.saveDraft();
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
