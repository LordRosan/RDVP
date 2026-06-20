import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import {
  DeviceArchiveCreateRequestForm,
  DeviceArchiveRequestStatus
} from '../../models/archive/DeviceArchiveRequestModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { ApiClient } from '../../services/common/ApiClient';
import { DeviceArchiveRequestService } from '../../services/archive/DeviceArchiveRequestService';
import { DeviceArchiveUpdateService } from '../../services/archive/DeviceArchiveUpdateService';
import { DeviceService } from '../../services/archive/DeviceService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

@Entry
@Component
struct DeviceArchiveCreate {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State deviceName: string = '';
  @State model: string = '';
  @State manufacturer: string = '';
  @State locationAddress: string = '';
  @State reason: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State normalizedDeviceCode: string = '-';
  @State fieldCount: number = 0;
  @State createTime: string = '';
  @State requestStatus: DeviceArchiveRequestStatus = DeviceArchiveRequestStatus.Draft;
  @State submitting: boolean = false;
  private prefilledDeviceCode: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit)) {
      return;
    }

    this.loadRouteParams();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.CreateForm()
          this.StatusPanel()
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
    this.backToArchiveCenter();
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
        this.backToArchiveCenter();
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
    Text('添加设备档案')
      .fontSize(34)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
    .alignSelf(ItemAlign.Start)
    .padding({ top: 0, bottom: 2 })
  }

  @Builder
  CreateForm() {
    Column({ space: 16 }) {
      this.DeviceCodeField()
      this.TextInputField('设备名称', '填写设备名称', this.deviceName, (value: string) => {
        this.deviceName = value;
        this.onFormChanged();
      })
      this.TextInputField('设备型号', '填写设备型号', this.model, (value: string) => {
        this.model = value;
        this.onFormChanged();
      })
      this.TextInputField('生产厂商', '填写生产厂商', this.manufacturer, (value: string) => {
        this.manufacturer = value;
        this.onFormChanged();
      })
      this.TextInputField('设备位置', '填写设备部署位置', this.locationAddress, (value: string) => {
        this.locationAddress = value;
        this.onFormChanged();
      })
      this.CreateTimeField()
      this.ReasonField()
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), $r('sys.symbol.plus_circle'),
        !this.submitting && !this.isSubmitted(), () => {
          this.submitCreateRequest();
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
  DeviceCodeField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备编号')

      TextInput({
        placeholder: '例如 RDVP-DEVICE-0100',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting && !this.isSubmitted() && this.prefilledDeviceCode.length === 0)
        .onChange((value: string) => {
          this.deviceCode = value;
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
          this.onFormChanged();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TextInputField(title: string, placeholder: string, value: string, change: (value: string) => void) {
    Column({ space: 10 }) {
      this.FieldTitle(title)

      TextInput({
        placeholder,
        text: value
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting && !this.isSubmitted())
        .onChange((input: string) => {
          change(input);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CreateTimeField() {
    Column({ space: 10 }) {
      this.FieldTitle('添加时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.createTime.length > 0 ? this.createTime : '选择添加时间')
          .fontSize(16)
          .fontColor(this.createTime.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
          if (this.submitting || this.isSubmitted()) {
            return;
          }

          this.showCreateTimePicker();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('添加原因')

      TextArea({
        placeholder: '填写设备来源、安装位置、投用依据或其他添加说明',
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
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting && !this.isSubmitted())
        .onChange((value: string) => {
          this.reason = value;
          this.onFormChanged();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('提交摘要')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '标准设备编号', value: this.normalizedDeviceCode, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '申请状态',
          value: DeviceArchiveUpdateService.formatRequestStatus(this.requestStatus),
          tone: this.getStatusTone(this.requestStatus)
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({ left: 18, right: 18 })
  }

  async submitCreateRequest(): Promise<void> {
    if (this.submitting || this.isSubmitted()) {
      return;
    }

    const form = this.buildForm();
    const validation = DeviceArchiveRequestService.validateCreateRequestForm(form);
    this.normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }
    this.fieldCount = DeviceArchiveRequestService.countCreateFields(form);

    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = AppColors.Danger;
      return;
    }

    this.submitting = true;
    const response = await DeviceArchiveRequestService.submitCreateRequestRemoteFirst(form);
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '添加申请提交失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.requestStatus = response.data === undefined ? DeviceArchiveRequestStatus.PendingReview : response.data.status;
    this.message = '添加申请已提交，等待管理员审核';
    this.messageTone = AppColors.Success;
  }

  buildForm(): DeviceArchiveCreateRequestForm {
    return {
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason,
      initiatedAt: this.createTime
    };
  }

  onFormChanged(): void {
    this.message = '';
    this.messageTone = AppColors.Danger;
    this.fieldCount = DeviceArchiveRequestService.countCreateFields(this.buildForm());
    if (!this.isSubmitted()) {
      this.requestStatus = DeviceArchiveRequestStatus.Draft;
    }
  }

  isSubmitted(): boolean {
    return this.requestStatus === DeviceArchiveRequestStatus.PendingReview;
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

  getStatusTone(status: DeviceArchiveRequestStatus): string {
    switch (status) {
      case DeviceArchiveRequestStatus.PendingReview:
        return AppColors.Warning;
      case DeviceArchiveRequestStatus.Approved:
        return AppColors.Success;
      case DeviceArchiveRequestStatus.Rejected:
        return AppColors.Danger;
      case DeviceArchiveRequestStatus.Withdrawn:
        return AppColors.TextSecondary;
      case DeviceArchiveRequestStatus.Draft:
      default:
        return AppColors.TextSecondary;
    }
  }

  loadRouteParams(): void {
    const router = this.getUIContext().getRouter();
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined) {
      const code = params['deviceCode'] as string | undefined;
      if (code !== undefined && code.trim().length > 0) {
        this.prefilledDeviceCode = code.trim();
        this.deviceCode = this.prefilledDeviceCode;
        this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
        if (this.normalizedDeviceCode.length === 0) {
          this.normalizedDeviceCode = '-';
        }
      }
    }
  }

  showCreateTimePicker(): void {
    if (this.submitting || this.isSubmitted()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.createTime),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.createTime = this.formatDateTime(value);
        this.onFormChanged();
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

  backToArchiveCenter(): void {
    if (!MainPageNavigator.backOrReplace(this.getUIContext(), 'pages/ArchiveCenter/ArchiveCenter')) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}


