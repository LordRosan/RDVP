import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import {
  ArchiveCreateRequestForm,
  ArchiveRequestStatus
} from '../models/ArchiveRequestModels';
import { PermissionCode } from '../../user/models/PermissionModels';
import { ArchiveRequestService } from '../services/ArchiveRequestService';
import { DeviceService } from '../services/DeviceService';
import { ApiClient } from '../../shared/services/ApiClient';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { AuthService } from '../../user/services/AuthService';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';
import { ArchiveImageDraft } from '../models/ArchiveImageModels';
import { ArchiveImageService } from '../services/ArchiveImageService';

interface CodeAvailabilityResult {
  available: boolean;
  reason?: string;
}

@Entry
@Component
struct ArchiveCreatePage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State deviceName: string = '';
  @State images: ArchiveImageDraft[] = [];
  @State processingImages: boolean = false;
  @State imageMessage: string = '';
  @State deviceType: string = '';
  @State model: string = '';
  @State manufacturer: string = '';
  @State commissionedAt: string = '';
  @State managementDepartment: string = '';
  @State locationAddress: string = '';
  @State createTime: string = '';
  @State reason: string = '';
  @State password: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State verifyMessage: string = '';
  @State verifyMessageTone: string = UiFeedbackTone.Danger;
  @State verifyResult: CodeAvailabilityResult | undefined = undefined;
  @State normalizedDeviceCode: string = '-';
  @State requestStatus: ArchiveRequestStatus = ArchiveRequestStatus.Draft;
  @State verifying: boolean = false;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(),
      PermissionCode.ArchiveCenterArchiveCreateRequestSubmit)) {
      return;
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.VerifySection()
          if (this.isDeviceCodeAvailable()) {
            this.CreateSection()
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
    this.backToArchiveCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToArchiveCenter();
      }
    })
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('添加档案')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Archive Create')
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
  VerifySection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '编号核验',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.DeviceCodeVerifyField()
        this.VerifyMessageText()
        if (this.verifyResult !== undefined) {
          this.VerifyResultRow()
        }
        this.ActionButton(this.getVerifyButtonLabel(), $r('sys.symbol.checkmark_circle'), this.canVerifyDeviceCode(),
          AppColors.Primary, () => {
            this.verifyDeviceCode();
          })
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
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CreateSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '添加信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.TextInputField('设备名称', '请输入设备名称', this.deviceName, (value: string) => {
          this.deviceName = value;
          this.onFormChanged();
        })
        this.ArchiveImagesField()
        this.TextInputField('设备类型', '请输入设备类型', this.deviceType, (value: string) => {
          this.deviceType = value;
          this.onFormChanged();
        })
        this.TextInputField('设备型号', '请输入设备型号', this.model, (value: string) => {
          this.model = value;
          this.onFormChanged();
        })
        this.TextInputField('生产厂商', '请输入生产厂商', this.manufacturer, (value: string) => {
          this.manufacturer = value;
          this.onFormChanged();
        })
        this.CommissionedAtField()
        this.TextInputField('管理部门', '请输入管理部门', this.managementDepartment, (value: string) => {
          this.managementDepartment = value;
          this.onFormChanged();
        })
        this.TextInputField('设备位置', '请输入设备位置', this.locationAddress, (value: string) => {
          this.locationAddress = value;
          this.onFormChanged();
        })
        this.CreateTimeField()
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
      this.ActionButton(this.getSubmitButtonLabel(), this.getSubmitIcon(), this.canSubmitCreate(),
        AppColors.Primary, () => {
          this.submitCreateRequest();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceCodeVerifyField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备编号')

      TextInput({
        placeholder: 'RDVP-DEVICE-XXXX',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.verifying && !this.submitting && !this.isSubmitted())
        .onChange((value: string) => {
          if (this.verifying || this.submitting || this.isSubmitted()) {
            return;
          }

          this.deviceCode = value;
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
          this.verifyMessage = '';
          this.verifyMessageTone = UiFeedbackTone.Danger;
          this.verifyResult = undefined;
          this.clearCreateState();
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
          if (this.submitting || this.isSubmitted()) {
            return;
          }

          change(input);
        })
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
        Text(`${this.images.length} / ${ArchiveImageService.getMaximumImageCount()}`)
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.images, (item: ArchiveImageDraft, index: number) => {
            this.ArchiveImageItem(item, index)
          }, (item: ArchiveImageDraft, index: number) => `${item.id === undefined ? 'selected' : item.id}-${index}`)

          if (this.images.length < ArchiveImageService.getMaximumImageCount()) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Column({ space: 7 }) {
                SymbolGlyph($r('sys.symbol.plus_circle'))
                  .fontSize(24)
                  .fontColor([AppColors.Primary])
                Text(this.processingImages ? '处理中' : '添加图片')
                  .fontSize(12)
                  .fontColor(AppColors.TextSecondary)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
              }
            }
            .width(82)
            .height(100)
            .backgroundColor(AppColors.SurfaceRaised)
            .borderRadius(AppRadii.Small)
            .border({ width: 1, color: AppColors.Border })
            .enabled(!this.processingImages && !this.submitting && !this.isSubmitted())
            .onClick(() => this.selectDeviceImages())
          }
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Top)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding(12)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(AppRadii.Medium)
      .border({ width: 1, color: AppColors.Border })

      if (this.imageMessage.length > 0) {
        InlineMessageSurface({
          message: this.imageMessage,
          tone: UiFeedbackTone.Danger
        })
      }
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
        .borderRadius(AppRadii.Small)
        .border({ width: 1, color: AppColors.Border })

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
    .enabled(enabled && !this.submitting && !this.isSubmitted())
    .onClick(action)
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
        if (this.submitting || this.isSubmitted()) {
          return;
        }

        this.showCommissionedAtPicker();
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

        Text(this.createTime.length > 0 ? this.createTime : '请选择添加时间')
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
        placeholder: '请输入添加原因',
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
        .enabled(!this.submitting && !this.isSubmitted())
        .onChange((value: string) => {
          if (this.submitting || this.isSubmitted()) {
            return;
          }

          this.reason = value;
          this.onFormChanged();
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
        .enabled(!this.submitting && !this.isSubmitted())
        .onChange((value: string) => {
          if (this.submitting || this.isSubmitted()) {
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
  VerifyResultRow() {
    Row({ space: 10 }) {
      SymbolGlyph(
        this.isDeviceCodeAvailable() ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.exclamationmark_circle'))
        .fontSize(20)
        .fontColor([this.isDeviceCodeAvailable() ? AppColors.Success : AppColors.Danger])

      Text(this.getDeviceCodeAvailabilityText())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDeviceCodeAvailable() ? AppColors.Success : AppColors.Danger)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.isDeviceCodeAvailable() ? AppColors.SuccessSurface : AppColors.DangerSurface)
    .borderRadius(AppRadii.Small)
    .alignItems(VerticalAlign.Center)
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
  VerifyMessageText() {
    if (this.verifyMessage.length > 0) {
      InlineMessageSurface({
        message: this.verifyMessage,
        tone: this.verifyMessageTone
      })
    }
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
  ActionButton(label: string, icon: Resource, enabled: boolean, color: string, action: () => void) {
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
    .backgroundColor(enabled ? color : AppColors.Disabled)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  async verifyDeviceCode(): Promise<void> {
    if (this.verifying || this.submitting || this.isSubmitted()) {
      return;
    }

    this.verifyMessage = '';
    this.verifyMessageTone = UiFeedbackTone.Danger;
    this.verifyResult = undefined;
    this.clearCreateState();
    const validation = DeviceService.validateDeviceCodeQuery({
      deviceCode: this.deviceCode
    });
    if (!validation.valid) {
      this.verifyMessage = validation.message;
      return;
    }

    const deviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    this.deviceCode = deviceCode;
    this.normalizedDeviceCode = deviceCode;
    if (!ApiClient.isConfigured()) {
      this.verifyMessage = UiFeedbackService.operationUnavailable('核验');
      return;
    }

    this.verifying = true;
    try {
      const code = encodeURIComponent(deviceCode);
      const response = await ApiClient.request<CodeAvailabilityResult>(
        `/api/v1/device-codes/${code}/availability`, 'GET', true);

      if (!response.success) {
        const error = response.error;
        this.verifyMessage = UiFeedbackService.codeQueryError(error, '设备编号', '核验');
        return;
      }

      if (response.data === undefined) {
        this.verifyMessage = UiFeedbackService.operationUnavailable('核验');
        return;
      }

      this.verifyResult = response.data;
    } finally {
      this.verifying = false;
    }
  }

  async submitCreateRequest(): Promise<void> {
    if (this.submitting || this.isSubmitted()) {
      return;
    }

    if (!this.isDeviceCodeAvailable()) {
      this.message = UiFeedbackService.requiredAction('先完成编号核验');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    const form = this.buildForm();
    const validation = ArchiveRequestService.validateCreateRequestForm(form);
    this.normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(this.deviceCode);
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

      const response = await ArchiveRequestService.submitCreateRequestRemoteFirst(form);
      if (!response.success) {
        this.message = UiFeedbackService.operationUnavailable('添加');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      this.requestStatus =
        response.data === undefined ? ArchiveRequestStatus.PendingReview : response.data.status;
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

    this.message = UiFeedbackService.passwordVerificationError(response.error, '添加');
    this.messageTone = UiFeedbackTone.Danger;
    return false;
  }

  buildForm(): ArchiveCreateRequestForm {
    return {
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      images: this.images,
      deviceType: this.deviceType,
      model: this.model,
      manufacturer: this.manufacturer,
      commissionedAt: this.commissionedAt,
      managementDepartment: this.managementDepartment,
      locationAddress: this.locationAddress,
      reason: this.reason,
      initiatedAt: this.createTime
    };
  }

  onFormChanged(): void {
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    if (!this.isSubmitted()) {
      this.requestStatus = ArchiveRequestStatus.Draft;
    }
  }

  clearCreateState(): void {
    this.deviceName = '';
    this.images = [];
    this.deviceType = '';
    this.model = '';
    this.manufacturer = '';
    this.commissionedAt = '';
    this.managementDepartment = '';
    this.locationAddress = '';
    this.createTime = '';
    this.reason = '';
    this.password = '';
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.requestStatus = ArchiveRequestStatus.Draft;
  }

  canVerifyDeviceCode(): boolean {
    return !this.verifying && !this.submitting && !this.isSubmitted();
  }

  canSubmitCreate(): boolean {
    return this.isDeviceCodeAvailable() && this.password.length > 0 && !this.submitting && !this.isSubmitted();
  }

  isDeviceCodeAvailable(): boolean {
    return this.verifyResult !== undefined && this.verifyResult.available;
  }

  getDeviceCodeAvailabilityText(): string {
    if (this.verifyResult === undefined) {
      return '-';
    }

    if (this.verifyResult.available) {
      return '设备编号可用';
    }

    return UiFeedbackService.deviceCodeAvailabilityMessage(this.verifyResult.available, this.verifyResult.reason);
  }

  isSubmitted(): boolean {
    return this.requestStatus === ArchiveRequestStatus.PendingReview;
  }

  getVerifyButtonLabel(): string {
    return this.verifying ? '核验中' : '核验';
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

  showCommissionedAtPicker(): void {
    if (this.submitting || this.isSubmitted()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(1970, 0, 1),
      end: new Date(2100, 11, 31),
      selected: this.resolveSelectedDateOnly(this.commissionedAt),
      showTime: false,
      onDateAccept: (value: Date) => {
        this.commissionedAt = this.formatDate(value);
        this.onFormChanged();
      }
    });
  }

  async selectDeviceImages(): Promise<void> {
    if (this.processingImages || this.submitting || this.isSubmitted()) {
      return;
    }

    try {
      this.processingImages = true;
      this.imageMessage = '';
      const picker = new photoAccessHelper.PhotoViewPicker();
      const selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: ArchiveImageService.getMaximumImageCount() - this.images.length
      });
      if (selection.photoUris.length === 0) {
        return;
      }
      const selectedImages: ArchiveImageDraft[] = [];
      for (let index = 0; index < selection.photoUris.length; index++) {
        selectedImages.push(await ArchiveImageService.compressSelectedImage(selection.photoUris[index]));
      }
      this.images = ArchiveImageService.appendSelectedDrafts(this.images, selectedImages);
      this.onFormChanged();
    } catch (err) {
      this.imageMessage = '图片处理失败，请重新选择有效图片';
    } finally {
      this.processingImages = false;
    }
  }

  removeImage(index: number): void {
    this.images = this.images.filter((item: ArchiveImageDraft, itemIndex: number) => itemIndex !== index);
    this.imageMessage = '';
    this.onFormChanged();
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
    this.imageMessage = '';
    this.onFormChanged();
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

  backToArchiveCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'archive/pages/ArchiveCenterPage', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
