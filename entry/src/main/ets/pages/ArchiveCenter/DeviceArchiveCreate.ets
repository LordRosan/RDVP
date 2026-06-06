import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceArchiveChangeRequestStatus } from '../../models/DeviceArchiveChangeModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import {
  DeviceArchiveCreateRequestForm,
  DeviceArchiveLifecycleService
} from '../../services/DeviceArchiveLifecycleService';
import { DeviceArchiveChangeService } from '../../services/DeviceArchiveChangeService';
import { DeviceService } from '../../services/DeviceService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

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
  @State requestStatus: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.Draft;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceCreate);
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
    Column({ space: 6 }) {
      Text('添加设备档案')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('提交新设备建档审核申请')
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
        .enabled(!this.submitting && !this.isSubmitted())
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
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('建档原因')

      TextArea({
        placeholder: '填写设备来源、安装位置、投用依据或其他建档说明',
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
      Text('提交状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '标准编号', value: this.normalizedDeviceCode, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '档案字段', value: `${this.fieldCount}项`, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '申请状态',
          value: DeviceArchiveChangeService.formatRequestStatus(this.requestStatus),
          tone: this.getStatusTone(this.requestStatus)
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
    const validation = DeviceArchiveLifecycleService.validateCreateRequestForm(form);
    this.normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }
    this.fieldCount = DeviceArchiveLifecycleService.countCreateFields(form);

    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = AppColors.Danger;
      return;
    }

    this.submitting = true;
    const response = await DeviceArchiveLifecycleService.submitCreateRequestRemoteFirst(form);
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '建档申请提交失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.requestStatus = response.data === undefined ? DeviceArchiveChangeRequestStatus.PendingReview : response.data.status;
    this.message = DeviceArchiveLifecycleService.isOfflineSyncQueuedResponse(response) ?
      '建档申请已保存至本地同步队列，恢复在线并同步成功后将提交审核' :
      '建档申请已提交，等待管理员审核';
    this.messageTone = AppColors.Success;
  }

  buildForm(): DeviceArchiveCreateRequestForm {
    return {
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason
    };
  }

  onFormChanged(): void {
    this.message = '';
    this.messageTone = AppColors.Danger;
    this.fieldCount = DeviceArchiveLifecycleService.countCreateFields(this.buildForm());
    if (!this.isSubmitted()) {
      this.requestStatus = DeviceArchiveChangeRequestStatus.Draft;
    }
  }

  isSubmitted(): boolean {
    return this.requestStatus === DeviceArchiveChangeRequestStatus.PendingReview ||
      this.requestStatus === DeviceArchiveChangeRequestStatus.PendingSync;
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
      case DeviceArchiveChangeRequestStatus.PendingSync:
        return AppColors.Warning;
      case DeviceArchiveChangeRequestStatus.Approved:
        return AppColors.Success;
      case DeviceArchiveChangeRequestStatus.Rejected:
        return AppColors.Danger;
      case DeviceArchiveChangeRequestStatus.Withdrawn:
        return AppColors.TextSecondary;
      case DeviceArchiveChangeRequestStatus.Draft:
      default:
        return AppColors.TextSecondary;
    }
  }

  backToArchiveCenter(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ArchiveCenter/ArchiveCenter' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
