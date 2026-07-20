import { photoAccessHelper } from '@kit.MediaLibraryKit';
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
import { ArchiveImageDraft } from '../models/ArchiveImageModels';
import { ArchiveImageService } from '../services/ArchiveImageService';

@Entry
@Component
struct ArchiveUpdatePage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State deviceName: string = '';
  @State images: ArchiveImageDraft[] = [];
  @State imagesChanged: boolean = false;
  @State processingImages: boolean = false;
  @State deviceType: string = '';
  @State model: string = '';
  @State manufacturer: string = '';
  @State commissionedAt: string = '';
  @State managementDepartment: string = '';
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

      Text('Archive Update')
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
        this.ArchiveImagesField()
        this.DeviceTypeField()
        this.DeviceModelField()
        this.ManufacturerField()
        this.CommissionedAtField()
        this.ManagementDepartmentField()
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
        this.canSubmitUpdate(), () => {
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
  ArchiveImagesField() {
    Column({ space: 10 }) {
      Row() {
        this.FieldTitle('设备图片')
        Blank()
        Text(`${this.images.length}/5`)
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
      }
      .width('100%')

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.images, (item: ArchiveImageDraft, index: number) => {
            this.ArchiveImageItem(item, index)
          }, (item: ArchiveImageDraft, index: number) => `${item.id === undefined ? item.previewUri : item.id}-${index}`)

          if (this.images.length < ArchiveImageService.getMaximumImageCount()) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Column({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.plus_circle'))
                  .fontSize(24)
                  .fontColor([AppColors.TextPrimary])
                Text(this.processingImages ? '处理中' : '添加图片')
                  .fontSize(12)
                  .fontColor(AppColors.TextSecondary)
              }
            }
            .width(82)
            .height(104)
            .backgroundColor(AppColors.FieldBackground)
            .borderRadius(AppRadii.Medium)
            .border({ width: 1, color: AppColors.Border })
            .enabled(!this.processingImages && !this.submitting && !this.isUpdateSubmitted())
            .onClick(() => this.selectDeviceImages())
          }
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ArchiveImageItem(item: ArchiveImageDraft, index: number) {
    Column({ space: 4 }) {
      Image(item.previewUri)
        .width(82)
        .height(72)
        .objectFit(ImageFit.Cover)
        .borderRadius(AppRadii.Medium)

      Row({ space: 2 }) {
        this.ImageIconButton($r('sys.symbol.chevron_backward'), index > 0, () => this.moveImage(index, -1))
        this.ImageIconButton($r('sys.symbol.trash'), true, () => this.removeImage(index))
        this.ImageIconButton($r('sys.symbol.chevron_forward'), index < this.images.length - 1,
          () => this.moveImage(index, 1))
      }
      .width(82)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width(82)
  }

  @Builder
  ImageIconButton(icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(14)
        .fontColor([enabled ? AppColors.TextPrimary : AppColors.TextTertiary])
    }
    .width(24)
    .height(24)
    .backgroundColor(AppColors.FieldBackground)
    .enabled(enabled && !this.submitting && !this.isUpdateSubmitted())
    .onClick(action)
  }

  @Builder
  DeviceTypeField() {
    this.ProfileTextField('设备类型', '填写新的设备类型', this.deviceType, (value: string) => {
      this.deviceType = value;
      this.message = '';
      this.updateFieldCount();
      this.saveDraft();
    })
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
  CommissionedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('启用日期')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.commissionedAt.length > 0 ? this.commissionedAt : '请选择启用日期')
          .fontSize(16)
          .fontColor(this.commissionedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
        if (this.submitting || this.isUpdateSubmitted()) {
          return;
        }

        this.showCommissionedAtPicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ManagementDepartmentField() {
    this.ProfileTextField('管理部门', '填写新的管理部门', this.managementDepartment, (value: string) => {
      this.managementDepartment = value;
      this.message = '';
      this.updateFieldCount();
      this.saveDraft();
    })
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
  ProfileTextField(title: string, placeholder: string, value: string, change: (value: string) => void) {
    Column({ space: 10 }) {
      this.FieldTitle(title)

      if (this.submitting || this.isUpdateSubmitted()) {
        Text(value)
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
          placeholder,
          text: value
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((input: string) => {
            change(input);
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
      images: this.images,
      imagesChanged: this.imagesChanged,
      deviceType: this.deviceType,
      model: this.model,
      manufacturer: this.manufacturer,
      commissionedAt: this.commissionedAt,
      managementDepartment: this.managementDepartment,
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

  canSubmitUpdate(): boolean {
    return this.hasDevice && this.password.length > 0 && !this.submitting && !this.isUpdateSubmitted();
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
      imageIds: device.images.map((item) => item.id),
      deviceType: device.deviceType,
      model: device.model,
      manufacturer: device.manufacturer,
      commissionedAt: device.commissionedAt,
      managementDepartment: device.managementDepartment,
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
      this.images = ArchiveImageService.createDraftsFromSummaries(device.images);
      this.imagesChanged = false;
      this.deviceType = device.deviceType;
      this.model = device.model;
      this.manufacturer = device.manufacturer;
      this.commissionedAt = device.commissionedAt;
      this.managementDepartment = device.managementDepartment;
      this.locationAddress = device.location.address;
      this.reason = '';
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    this.updateFieldCount();
  }

  applyDraft(draft: ArchiveUpdateDraft): void {
    this.deviceCode = draft.deviceCode;
    this.deviceName = draft.deviceName;
    this.images = draft.images;
    this.imagesChanged = draft.imagesChanged;
    this.deviceType = draft.deviceType;
    this.model = draft.model;
    this.manufacturer = draft.manufacturer;
    this.commissionedAt = draft.commissionedAt;
    this.managementDepartment = draft.managementDepartment;
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
      images: this.images,
      imagesChanged: this.imagesChanged,
      deviceType: this.deviceType,
      model: this.model,
      manufacturer: this.manufacturer,
      commissionedAt: this.commissionedAt,
      managementDepartment: this.managementDepartment,
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

  showCommissionedAtPicker(): void {
    if (this.submitting || this.isUpdateSubmitted()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(1970, 0, 1),
      end: new Date(2100, 11, 31),
      selected: this.resolveSelectedDateOnly(this.commissionedAt),
      showTime: false,
      onDateAccept: (value: Date) => {
        this.commissionedAt = this.formatDate(value);
        this.message = '';
        this.updateFieldCount();
        this.saveDraft();
      }
    });
  }

  async selectDeviceImages(): Promise<void> {
    if (this.processingImages || this.submitting || this.isUpdateSubmitted()) {
      return;
    }

    try {
      this.processingImages = true;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: ArchiveImageService.getMaximumImageCount() - this.images.length
      });
      const selectedImages: ArchiveImageDraft[] = [];
      for (let index = 0; index < selection.photoUris.length; index++) {
        selectedImages.push(await ArchiveImageService.compressSelectedImage(selection.photoUris[index]));
      }
      this.images = this.images.concat(selectedImages);
      this.imagesChanged = true;
      this.message = '';
      this.updateFieldCount();
      this.saveDraft();
    } catch (err) {
      this.message = '图片处理失败，请选择尺寸较小的有效图片';
      this.messageTone = UiFeedbackTone.Danger;
    } finally {
      this.processingImages = false;
    }
  }

  removeImage(index: number): void {
    this.images = this.images.filter((item: ArchiveImageDraft, itemIndex: number) => itemIndex !== index);
    this.imagesChanged = true;
    this.message = '';
    this.updateFieldCount();
    this.saveDraft();
  }

  moveImage(index: number, offset: number): void {
    const target = index + offset;
    if (target < 0 || target >= this.images.length) {
      return;
    }
    const reordered = this.images.slice();
    const selected = reordered[index];
    reordered[index] = reordered[target];
    reordered[target] = selected;
    this.images = reordered;
    this.imagesChanged = true;
    this.message = '';
    this.updateFieldCount();
    this.saveDraft();
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

  resolveSelectedDateOnly(value: string): Date {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return new Date();
    }

    const segments = trimmed.split('-');
    if (segments.length !== 3) {
      return new Date();
    }

    const year = Number(segments[0]);
    const month = Number(segments[1]);
    const day = Number(segments[2]);
    if (year !== year || month !== month || day !== day) {
      return new Date();
    }

    return new Date(year, month - 1, day);
  }

  formatDateTime(value: Date): string {
    return `${value.getFullYear()}-${this.pad2(value.getMonth() + 1)}-${this.pad2(value.getDate())} ${this.pad2(
      value.getHours())}:${this.pad2(value.getMinutes())}`;
  }

  formatDate(value: Date): string {
    return `${value.getFullYear()}-${this.pad2(value.getMonth() + 1)}-${this.pad2(value.getDate())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
