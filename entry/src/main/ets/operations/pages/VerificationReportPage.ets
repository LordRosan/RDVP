import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { PermissionCode } from '../../user/models/PermissionModels';
import {
  VerificationDeviceStatus,
  VerificationItemResult,
  VerificationMethod,
  VerificationReportForm,
  VerificationReportItem,
  VerificationResult,
  VerificationType
} from '../models/VerificationReportModels';
import { DeviceService } from '../../archive/services/DeviceService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { VerificationReportService } from '../services/VerificationReportService';
import { AuthService } from '../../user/services/AuthService';
import { SessionStore } from '../../user/stores/SessionStore';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { AppRoutes } from '../../shared/navigation/AppRoutes';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';
import { VerificationReportFlowStore } from '../stores/VerificationReportFlowStore';

const VERIFICATION_TYPE_VALUES: string[] = [
  `${VerificationType.Routine}`,
  `${VerificationType.Temporary}`,
  `${VerificationType.Special}`,
  `${VerificationType.Initial}`,
  `${VerificationType.Sampling}`,
  `${VerificationType.Other}`
];
const VERIFICATION_TYPE_LABELS: string[] = ['例行', '临时', '专项', '首次', '抽检', '其他'];
const DEVICE_STATUS_VALUES: string[] = [
  `${VerificationDeviceStatus.Running}`,
  `${VerificationDeviceStatus.Standby}`,
  `${VerificationDeviceStatus.Stopped}`,
  `${VerificationDeviceStatus.Offline}`,
  `${VerificationDeviceStatus.Unknown}`,
  `${VerificationDeviceStatus.Other}`
];
const DEVICE_STATUS_LABELS: string[] = ['运行', '待机', '停机', '离线', '未知', '其他'];
const VERIFICATION_METHOD_VALUES: string[] = [
  `${VerificationMethod.OnsiteObservation}`,
  `${VerificationMethod.IdentificationCheck}`,
  `${VerificationMethod.FunctionTest}`,
  `${VerificationMethod.DataReading}`,
  `${VerificationMethod.RemoteConfirmation}`,
  `${VerificationMethod.Other}`
];
const VERIFICATION_METHOD_LABELS: string[] = ['现场观察', '编号核对', '功能测试', '数据读取', '远程确认', '其他方式'];

@Entry
@Component
struct VerificationReportPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State verificationType: string = '';
  @State deviceStatus: string = '';
  @State verificationMethod: string = '';
  @State verificationItems: VerificationReportItem[] = VerificationReportService.createDefaultVerificationItems();
  @State description: string = '';
  @State verifiedAt: string = '';
  @State password: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State normalizedDeviceCode: string = '-';
  @State submitting: boolean = false;
  @State submitted: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OperationsCenterDeviceVerificationSubmit)) {
      return;
    }
  }

  onPageShow(): void {
    if (VerificationReportFlowStore.consumeFaultReportSubmitted()) {
      this.resetAfterFaultReportSubmitted();
      return;
    }

    if (VerificationReportFlowStore.consumeFaultReportDiscarded()) {
      this.resetAfterFaultReportDiscarded();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.VerificationForm()
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
    this.backToOperationsCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToOperationsCenter();
      }
    })
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('核验与报修')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Verification And Fault Report')
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
  VerificationForm() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '核验信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.DeviceCodeField()
        this.VerifiedAtField()
        this.VerificationTypeSelector()
        this.DeviceStatusSelector()
        this.VerificationMethodSelector()
        this.VerificationItemSection()
        this.ResultDisplay()
        this.DescriptionField()
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

      if (this.isNormalVerification()) {
        this.PasswordSection()
      }

      this.MessageText()
      this.PrimaryActionButton()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceCodeField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备编号')

      TextInput({
        placeholder: '请输入设备编号',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
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
        .enabled(!this.submitting && !this.submitted)
        .onChange((value: string) => {
          this.deviceCode = value;
          this.markFormChanged();
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerifiedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('核验时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.verifiedAt.length > 0 ? this.verifiedAt : '请选择核验时间')
          .fontSize(16)
          .fontColor(this.verifiedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
        if (this.submitting || this.submitted) {
          return;
        }

        this.showVerifiedAtPicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerificationTypeSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('核验类型')
      this.VerificationTypeSelectionField()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceStatusSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('设备状态')
      this.DeviceStatusSelectionField()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerificationMethodSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('核验方式')
      this.VerificationMethodSelectionField()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerificationTypeSelectionField() {
    Row({ space: 10 }) {
      Text(VerificationReportService.formatVerificationTypeSelection(this.verificationType as VerificationType))
        .fontSize(16)
        .fontColor(this.verificationType.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
    .enabled(!this.submitting && !this.submitted)
    .onClick(() => {
      if (this.submitting || this.submitted) {
        return;
      }

      this.showVerificationTypePicker();
    })
  }

  @Builder
  DeviceStatusSelectionField() {
    Row({ space: 10 }) {
      Text(VerificationReportService.formatDeviceStatusSelection(this.deviceStatus as VerificationDeviceStatus))
        .fontSize(16)
        .fontColor(this.deviceStatus.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
    .enabled(!this.submitting && !this.submitted)
    .onClick(() => {
      if (this.submitting || this.submitted) {
        return;
      }

      this.showDeviceStatusPicker();
    })
  }

  @Builder
  VerificationMethodSelectionField() {
    Row({ space: 10 }) {
      Text(VerificationReportService.formatVerificationMethodSelection(this.verificationMethod as VerificationMethod))
        .fontSize(16)
        .fontColor(this.verificationMethod.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
    .enabled(!this.submitting && !this.submitted)
    .onClick(() => {
      if (this.submitting || this.submitted) {
        return;
      }

      this.showVerificationMethodPicker();
    })
  }

  @Builder
  VerificationItemSection() {
    Column({ space: 8 }) {
      this.FieldTitle('核验项')
      this.VerificationItemOptionHeader()

      ForEach(this.verificationItems, (item: VerificationReportItem, index: number) => {
        this.VerificationItemRow(item, index)
      }, (item: VerificationReportItem) => item.itemCode)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerificationItemOptionHeader() {
    Row({ space: 10 }) {
      Blank()
        .layoutWeight(1)

      Row() {
        this.ItemResultHeaderLabel(VerificationItemResult.Passed)
        this.ItemResultHeaderLabel(VerificationItemResult.Failed)
        this.ItemResultHeaderLabel(VerificationItemResult.NotApplicable)
      }
      .width(144)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12, right: 10 })
  }

  @Builder
  ItemResultHeaderLabel(result: VerificationItemResult) {
    Text(VerificationReportService.formatVerificationItemResult(result))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getItemResultTone(result))
      .width(48)
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  VerificationItemRow(item: VerificationReportItem, index: number) {
    Column() {
      Row({ space: 10 }) {
        Text(item.itemName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Row() {
          this.ItemResultRadio(index, item.itemCode, VerificationItemResult.Passed)
          this.ItemResultRadio(index, item.itemCode, VerificationItemResult.Failed)
          this.ItemResultRadio(index, item.itemCode, VerificationItemResult.NotApplicable)
        }
        .width(144)
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: 12,
      right: 10
    })
    .backgroundColor(AppColors.SurfaceMuted)
    .borderRadius(14)
    .border({ width: 1, color: AppColors.Divider })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ItemResultRadio(index: number, itemCode: string, result: VerificationItemResult) {
    Row() {
      Radio({
        value: `${result}`,
        group: `verification-item-${itemCode}`
      })
        .checked(this.verificationItems[index].result === result)
        .radioStyle({
          checkedBackgroundColor: this.getItemResultTone(result),
          uncheckedBorderColor: this.getItemResultTone(result),
          indicatorColor: AppColors.OnPrimary
        })
        .enabled(!this.submitting && !this.submitted)
        .onChange((checked: boolean) => {
          if (checked) {
            this.updateVerificationItemResult(index, result);
          }
        })
    }
    .width(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.updateVerificationItemResult(index, result);
    })
  }

  @Builder
  ResultDisplay() {
    Column({ space: 10 }) {
      this.FieldTitle('核验结果')

      Row({ space: 10 }) {
        SymbolGlyph(this.getVerificationResult() === VerificationResult.Abnormal ?
          $r('sys.symbol.exclamationmark_shield_fill') : $r('sys.symbol.checkmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(VerificationReportService.formatVerificationResult(this.getVerificationResult()))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .layoutWeight(1)
          .maxLines(1)
      }
      .height(50)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.getResultTone(this.getVerificationResult()))
      .borderRadius(18)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('核验说明')

      TextArea({
        placeholder: '请输入核验说明',
        text: this.description
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
        .enabled(!this.submitting && !this.submitted)
        .onChange((value: string) => {
          this.description = value;
          this.markFormChanged();
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
        .enabled(!this.submitting && !this.submitted)
        .onChange((value: string) => {
          if (this.submitting || this.submitted) {
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
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: this.messageTone
      })
    }
  }

  @Builder
  PrimaryActionButton() {
    Button({
      type: ButtonType.Capsule,
      stateEffect: this.isPrimaryActionEnabled()
    }) {
      Row({ space: 8 }) {
        SymbolGlyph(this.requiresFaultReport() ? $r('sys.symbol.chevron_forward') : $r('sys.symbol.checkmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(VerificationReportService.formatVerificationStepActionLabel(
          `${this.getVerificationResult()}`,
          this.submitting,
          this.submitted
        ))
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
    .backgroundColor(this.isPrimaryActionEnabled() ? AppColors.Primary : AppColors.Disabled)
    .enabled(this.isPrimaryActionEnabled())
    .onClick(() => {
      this.handlePrimaryAction();
    })
  }

  async handlePrimaryAction(): Promise<void> {
    if (this.requiresFaultReport()) {
      this.openFaultReportPage();
      return;
    }

    await this.submitNormalVerification();
  }

  openFaultReportPage(): void {
    if (this.submitting || this.submitted) {
      return;
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    const validation = VerificationReportService.validateAbnormalVerificationStepForm(
      this.buildVerificationForm());
    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    if (!SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceFaultReportSubmit)) {
      this.message = UiFeedbackService.operationUnavailable('报修报告');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    VerificationReportFlowStore.startFaultReportFlow(this.buildVerificationForm());
    AppNavigator.push(this.getUIContext(), AppRoutes.FaultReportPage, () => {
      this.message = UiFeedbackService.operationUnavailable('报修报告');
      this.messageTone = UiFeedbackTone.Danger;
    });
  }

  async submitNormalVerification(): Promise<void> {
    if (this.submitting || this.submitted) {
      return;
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    const validation = VerificationReportService.validateVerificationForm(this.buildVerificationForm());
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

      const response = await VerificationReportService.submitVerificationReportRemoteFirst(
        this.buildVerificationForm());
      if (!response.success) {
        const error = response.error;
        this.message = UiFeedbackService.operationError(error, '提交');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      this.message = '提交成功，核验报告已进入审核';
      this.messageTone = UiFeedbackTone.Success;
      this.password = '';
      this.submitted = true;
    } finally {
      this.submitting = false;
    }
  }

  buildVerificationForm(): VerificationReportForm {
    return {
      deviceCode: this.deviceCode,
      verificationType: this.verificationType as VerificationType,
      deviceStatus: this.deviceStatus as VerificationDeviceStatus,
      verificationMethod: this.verificationMethod as VerificationMethod,
      items: this.verificationItems.map((item: VerificationReportItem): VerificationReportItem => {
        const formItem: VerificationReportItem = {
          itemCode: item.itemCode,
          itemName: item.itemName,
          result: item.result
        };
        return formItem;
      }),
      description: this.description,
      verifiedAt: this.verifiedAt,
      remark: ''
    };
  }

  async verifyPasswordForSubmit(password: string): Promise<boolean> {
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(password);
    if (response.success && response.data === true) {
      return true;
    }

    this.message = UiFeedbackService.passwordVerificationError(response.error, '提交');
    this.messageTone = UiFeedbackTone.Danger;
    return false;
  }

  isPrimaryActionEnabled(): boolean {
    return VerificationReportService.canUseVerificationStepAction(
      `${this.getVerificationResult()}`,
      this.password,
      this.submitting,
      this.submitted
    );
  }

  requiresFaultReport(): boolean {
    return this.getVerificationResult() === VerificationResult.Abnormal;
  }

  isNormalVerification(): boolean {
    return this.getVerificationResult() === VerificationResult.Normal;
  }

  getVerificationResult(): VerificationResult {
    return VerificationReportService.resolveVerificationResult(this.verificationItems);
  }

  getResultTone(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return AppColors.Success;
      case VerificationResult.Abnormal:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  getItemResultTone(result: VerificationItemResult): string {
    switch (result) {
      case VerificationItemResult.Passed:
        return AppColors.Success;
      case VerificationItemResult.Failed:
        return AppColors.Danger;
      case VerificationItemResult.NotApplicable:
        return AppColors.Log;
      default:
        return AppColors.TextSecondary;
    }
  }

  getVerificationTypeIndex(): number {
    return this.indexOfPickerValue(VERIFICATION_TYPE_VALUES, this.verificationType);
  }

  getDeviceStatusIndex(): number {
    return this.indexOfPickerValue(DEVICE_STATUS_VALUES, this.deviceStatus);
  }

  getVerificationMethodIndex(): number {
    return this.indexOfPickerValue(VERIFICATION_METHOD_VALUES, this.verificationMethod);
  }

  showVerificationTypePicker(): void {
    const previousValue = this.verificationType;
    this.showSingleSelectionPicker(
      VERIFICATION_TYPE_LABELS,
      this.getVerificationTypeIndex(),
      (index: number, label: string) => {
        this.applyVerificationTypePickerSelection(index, label);
      },
      () => {
        this.verificationType = previousValue;
      }
    );
  }

  showDeviceStatusPicker(): void {
    const previousValue = this.deviceStatus;
    this.showSingleSelectionPicker(
      DEVICE_STATUS_LABELS,
      this.getDeviceStatusIndex(),
      (index: number, label: string) => {
        this.applyDeviceStatusPickerSelection(index, label);
      },
      () => {
        this.deviceStatus = previousValue;
      }
    );
  }

  showVerificationMethodPicker(): void {
    const previousValue = this.verificationMethod;
    this.showSingleSelectionPicker(
      VERIFICATION_METHOD_LABELS,
      this.getVerificationMethodIndex(),
      (index: number, label: string) => {
        this.applyVerificationMethodPickerSelection(index, label);
      },
      () => {
        this.verificationMethod = previousValue;
      }
    );
  }

  showSingleSelectionPicker(
    range: string[],
    selected: number,
    applySelection: (index: number, label: string) => void,
    restoreSelection: () => void
  ): void {
    if (this.submitting || this.submitted) {
      return;
    }

    this.getUIContext().showTextPickerDialog({
      range,
      selected,
      canLoop: false,
      defaultPickerItemHeight: 38,
      selectedTextStyle: {
        color: AppColors.Primary,
        font: {
          size: 17,
          weight: FontWeight.Bold
        }
      },
      textStyle: {
        color: AppColors.TextSecondary,
        font: {
          size: 14,
          weight: FontWeight.Medium
        }
      },
      onAccept: (value: TextPickerResult) => {
        this.applySinglePickerResult(range, value, applySelection);
      },
      onChange: (value: TextPickerResult) => {
        this.applySinglePickerResult(range, value, applySelection);
      },
      onScrollStop: (value: TextPickerResult) => {
        this.applySinglePickerResult(range, value, applySelection);
      },
      onCancel: () => {
        restoreSelection();
      }
    });
  }

  applySinglePickerResult(
    range: string[],
    result: TextPickerResult,
    applySelection: (index: number, label: string) => void
  ): void {
    const index = this.normalizeSinglePickerValue(range, result.value, result.index);
    applySelection(index, range[this.normalizePickerIndex(index, range.length)]);
  }

  applyVerificationTypePickerSelection(index: number, label: string): void {
    const value = VerificationReportService.resolveVerificationTypeSelection(label);
    if (value !== undefined) {
      this.verificationType = `${value}`;
      this.markFormChanged();
      return;
    }

    this.applyPickerIndex('type', index);
  }

  applyDeviceStatusPickerSelection(index: number, label: string): void {
    const value = VerificationReportService.resolveDeviceStatusSelection(label);
    if (value !== undefined) {
      this.deviceStatus = `${value}`;
      this.markFormChanged();
      return;
    }

    this.applyPickerIndex('status', index);
  }

  applyVerificationMethodPickerSelection(index: number, label: string): void {
    const value = VerificationReportService.resolveVerificationMethodSelection(label);
    if (value !== undefined) {
      this.verificationMethod = `${value}`;
      this.markFormChanged();
      return;
    }

    this.applyPickerIndex('method', index);
  }

  applyPickerIndex(group: string, index: number): void {
    if (this.submitting || this.submitted) {
      return;
    }

    if (group === 'type') {
      this.verificationType = VERIFICATION_TYPE_VALUES[this.normalizePickerIndex(index, VERIFICATION_TYPE_VALUES.length)];
    } else if (group === 'status') {
      this.deviceStatus = DEVICE_STATUS_VALUES[this.normalizePickerIndex(index, DEVICE_STATUS_VALUES.length)];
    } else {
      this.verificationMethod =
        VERIFICATION_METHOD_VALUES[this.normalizePickerIndex(index, VERIFICATION_METHOD_VALUES.length)];
    }

    this.markFormChanged();
  }

  normalizeSinglePickerIndex(index: number | number[]): number {
    if (typeof index === 'number') {
      return index;
    }

    if (index.length === 0) {
      return 0;
    }

    return index[0];
  }

  normalizeSinglePickerValue(range: string[], value: string | string[], fallbackIndex: number | number[]): number {
    const fallback = this.normalizeSinglePickerIndex(fallbackIndex);
    const selectedLabel = this.normalizeSinglePickerLabel(value);
    if (selectedLabel.length === 0) {
      return fallback;
    }

    return this.indexOfPickerLabel(range, selectedLabel, fallback);
  }

  normalizeSinglePickerLabel(value: string | string[]): string {
    if (typeof value === 'string') {
      return value;
    }

    if (value.length === 0) {
      return '';
    }

    return value[0];
  }

  indexOfPickerLabel(values: string[], label: string, fallbackIndex: number): number {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === label) {
        return index;
      }
    }

    return fallbackIndex;
  }

  indexOfPickerValue(values: string[], value: string): number {
    const index = values.indexOf(value);
    if (index < 0) {
      return 0;
    }

    return index;
  }

  normalizePickerIndex(index: number, length: number): number {
    if (length <= 0 || index !== index || index < 0) {
      return 0;
    }

    if (index >= length) {
      return length - 1;
    }

    return Math.floor(index);
  }

  updateVerificationItemResult(index: number, result: VerificationItemResult): void {
    if (this.submitting || this.submitted || index < 0 || index >= this.verificationItems.length) {
      return;
    }

    const items = this.verificationItems.map((item: VerificationReportItem, itemIndex: number): VerificationReportItem => {
      const updatedItem: VerificationReportItem = {
        itemCode: item.itemCode,
        itemName: item.itemName,
        result: itemIndex === index ? result : item.result
      };
      return updatedItem;
    });
    this.verificationItems = items;
    this.password = '';
    this.markFormChanged();
  }

  markFormChanged(): void {
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.submitted = false;
  }

  resetAfterFaultReportSubmitted(): void {
    this.deviceCode = '';
    this.verificationType = '';
    this.deviceStatus = '';
    this.verificationMethod = '';
    this.verificationItems = VerificationReportService.createDefaultVerificationItems();
    this.description = '';
    this.verifiedAt = '';
    this.password = '';
    this.normalizedDeviceCode = '-';
    this.submitting = false;
    this.submitted = false;
    this.message = '提交成功，核验报告将先进入审核；核验审核通过后报修报告进入审核';
    this.messageTone = UiFeedbackTone.Success;
  }

  resetAfterFaultReportDiscarded(): void {
    this.deviceCode = '';
    this.verificationType = '';
    this.deviceStatus = '';
    this.verificationMethod = '';
    this.verificationItems = VerificationReportService.createDefaultVerificationItems();
    this.description = '';
    this.verifiedAt = '';
    this.password = '';
    this.normalizedDeviceCode = '-';
    this.submitting = false;
    this.submitted = false;
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
  }

  showVerifiedAtPicker(): void {
    if (this.submitting || this.submitted) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.verifiedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.verifiedAt = this.formatDateTime(value);
        this.markFormChanged();
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

  backToOperationsCenter(): void {
    VerificationReportFlowStore.clearFlow();
    AppNavigator.backOrReplace(this.getUIContext(), AppRoutes.OperationsCenterPage, {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
