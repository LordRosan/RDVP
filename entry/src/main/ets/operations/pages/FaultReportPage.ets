import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { FaultSeverity, FaultSubtype, FaultType } from '../models/FaultModels';
import {
  AbnormalVerificationSubmissionForm,
  VerificationReportForm,
  VerificationResult
} from '../models/VerificationReportModels';
import { PermissionCode } from '../../user/models/PermissionModels';
import { DeviceService } from '../../archive/services/DeviceService';
import { FaultReportService, FaultSubtypeOption, FaultTypeSelection } from '../services/FaultReportService';
import { VerificationReportService } from '../services/VerificationReportService';
import { LocationService, LocationResolutionResult } from '../services/LocationService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { AuthService } from '../../user/services/AuthService';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { AppRoutes } from '../../shared/navigation/AppRoutes';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';
import { VerificationReportFlowStore } from '../stores/VerificationReportFlowStore';

const FAULT_TYPE_VALUES: string[] = [
  `${FaultType.OperationAbnormal}`,
  `${FaultType.HardwareDamage}`,
  `${FaultType.CommunicationFault}`,
  `${FaultType.LogicFault}`,
  `${FaultType.EnergyFault}`,
  `${FaultType.ExternalFactor}`,
  `${FaultType.Other}`
];
const SEVERITY_VALUES: string[] = [
  `${FaultSeverity.Emergency}`,
  `${FaultSeverity.Severe}`,
  `${FaultSeverity.General}`,
  `${FaultSeverity.Minor}`
];
const SEVERITY_LABELS: string[] = ['紧急', '严重', '一般', '轻微'];

@Entry
@Component
struct FaultReportPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State faultType: string = '';
  @State faultSubtype: string = '';
  @State severity: string = '';
  @State occurredAt: string = '';
  @State faultDescription: string = '';
  @State password: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State submitting: boolean = false;
  @State submitted: boolean = false;
  @State locating: boolean = false;
  @State hasLocation: boolean = false;
  @State longitude: number = 0;
  @State latitude: number = 0;
  @State locationAccuracy: number = 0;
  @State hasVerification: boolean = false;
  private showingLeaveDialog: boolean = false;
  private verification: VerificationReportForm = VerificationReportService.createEmptyAbnormalVerificationForm();

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OperationsCenterDeviceFaultReportSubmit)) {
      return;
    }

    this.loadVerificationContext();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          if (this.hasVerification) {
            this.FaultReportFormBody()
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
    this.handleBackAction();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.handleBackAction();
      }
    })
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('报修报告')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Fault Report')
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
  FaultReportFormBody() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '报修信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.ReadOnlyField('设备编号', this.deviceCode)
        this.OccurredAtField()
        this.LocationField()
        this.FaultTypePicker()
        this.SeverityPicker()
        this.FaultDescriptionField()
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
      this.SubmitActionButton()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReadOnlyField(title: string, value: string) {
    Column({ space: 10 }) {
      this.FieldTitle(title)

      TextInput({
        placeholder: title,
        text: value
      })
        .height(56)
        .fontSize(16)
        .fontColor(AppColors.TextSecondary)
        .backgroundColor(AppColors.SurfaceMuted)
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: AppColors.Divider
        })
        .enabled(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  OccurredAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('故障时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.occurredAt.length > 0 ? this.occurredAt : '请选择故障时间')
          .fontSize(16)
          .fontColor(this.occurredAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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

        this.showOccurredAtPicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LocationField() {
    Column({ space: 10 }) {
      this.FieldTitle('故障地点')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.location_up'))
          .fontSize(20)
          .fontColor([this.hasLocation ? AppColors.Success : AppColors.TextPrimary])

        Column({ space: 3 }) {
          Text(this.hasLocation ? FaultReportService.formatFaultLocation(this.longitude, this.latitude) : '请获取故障地点')
            .fontSize(15)
            .fontColor(this.hasLocation ? AppColors.TextPrimary : AppColors.TextTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.hasLocation ? `精度 ${this.locationAccuracy.toFixed(0)} m` : '定位成功后才可提交')
            .fontSize(12)
            .fontColor(AppColors.TextTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.locating ? '定位中' : this.hasLocation ? '重新获取' : '获取')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.Primary)
          .maxLines(1)
      }
      .height(64)
      .width('100%')
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({
        left: 16,
        right: 16
      })
      .border({
        width: 1,
        color: this.hasLocation ? AppColors.Success : AppColors.Border
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.resolveFaultLocation();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FaultTypePicker() {
    Column({ space: 10 }) {
      this.FieldTitle('故障类型')
      this.FaultTypeSelectionField()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SeverityPicker() {
    Column({ space: 10 }) {
      this.FieldTitle('故障等级')
      this.SeveritySelectionField()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FaultTypeSelectionField() {
    Row({ space: 10 }) {
      Text(FaultReportService.formatFaultTypeSelection(this.faultType as FaultType, this.faultSubtype as FaultSubtype))
        .fontSize(16)
        .fontColor(this.isFaultTypeSelectionReady() ? AppColors.TextPrimary : AppColors.TextTertiary)
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

      this.showFaultTypePicker();
    })
  }

  @Builder
  SeveritySelectionField() {
    Row({ space: 10 }) {
      Text(FaultReportService.formatSeveritySelection(this.severity as FaultSeverity))
        .fontSize(16)
        .fontColor(this.severity.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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

      this.showSeverityPicker();
    })
  }

  @Builder
  FaultDescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('故障说明')

      TextArea({
        placeholder: '请输入故障说明',
        text: this.faultDescription
      })
        .height(128)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(800)
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
          this.faultDescription = value;
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
  EmptyPanel() {
    Column({ space: 12 }) {
      InlineMessageSurface({
        message: this.message,
        tone: this.messageTone
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
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SubmitActionButton() {
    Button({
      type: ButtonType.Capsule,
      stateEffect: this.isSubmitActionEnabled()
    }) {
      Row({ space: 8 }) {
        SymbolGlyph(this.submitted ? $r('sys.symbol.chevron_backward') : $r('sys.symbol.checkmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.submitting ? '提交中' : this.submitted ? '返回核验' : '提交')
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
    .backgroundColor(this.isSubmitActionEnabled() ? AppColors.Primary : AppColors.Disabled)
    .enabled(this.isSubmitActionEnabled())
    .onClick(() => {
      this.handleSubmitAction();
    })
  }

  loadVerificationContext(): void {
    const pending = VerificationReportFlowStore.getPendingAbnormalVerification();
    if (pending === undefined ||
      VerificationReportService.resolveVerificationResult(pending.items) !== VerificationResult.Abnormal) {
      this.hasVerification = false;
      this.message = UiFeedbackService.operationUnavailable('报修报告');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.verification = pending;
    this.deviceCode = DeviceService.normalizeDeviceCode(pending.deviceCode);
    if (this.deviceCode.length === 0) {
      this.deviceCode = pending.deviceCode;
    }

    this.hasVerification = true;
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
  }

  async handleSubmitAction(): Promise<void> {
    if (this.submitted) {
      this.backToVerificationReport();
      return;
    }

    await this.submitFaultReport();
  }

  async submitFaultReport(): Promise<void> {
    if (this.submitting || this.submitted || !this.hasVerification) {
      return;
    }

    const form = this.buildForm();
    const validation = VerificationReportService.validateAbnormalVerificationSubmissionForm(form);
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

      const response = await VerificationReportService.submitAbnormalVerificationRemoteFirst(form);
      if (!response.success) {
        const error = response.error;
        this.message = UiFeedbackService.operationError(error, '提交');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      VerificationReportFlowStore.markFaultReportSubmitted();
      this.password = '';
      this.submitted = true;
      this.message = '提交成功，核验报告将先进入审核；核验审核通过后报修报告进入审核';
      this.messageTone = UiFeedbackTone.Success;
    } finally {
      this.submitting = false;
    }
  }

  buildForm(): AbnormalVerificationSubmissionForm {
    return {
      verification: this.verification,
      faultReport: {
        deviceCode: this.verification.deviceCode,
        faultType: this.faultType as FaultType,
        faultSubtype: this.faultSubtype as FaultSubtype,
        severity: this.severity as FaultSeverity,
        occurredAt: this.occurredAt,
        description: this.faultDescription,
        sceneCondition: '',
        longitude: this.hasLocation ? this.longitude : undefined,
        latitude: this.hasLocation ? this.latitude : undefined
      }
    };
  }

  async resolveFaultLocation(): Promise<void> {
    if (this.locating || this.submitting || this.submitted) {
      return;
    }

    this.locating = true;
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    try {
      const result: LocationResolutionResult =
        await LocationService.resolveCurrentLocation(this.getUIContext().getHostContext());
      if (!result.success || result.coordinates === undefined) {
        this.hasLocation = false;
        this.message = `${result.message}，报修报告需定位成功后才可提交`;
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      this.hasLocation = true;
      this.longitude = result.coordinates.longitude;
      this.latitude = result.coordinates.latitude;
      this.locationAccuracy = result.coordinates.accuracy;
      this.message = result.message;
      this.messageTone = UiFeedbackTone.Success;
    } finally {
      this.locating = false;
    }
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

  isSubmitActionEnabled(): boolean {
    return this.submitted ||
      (this.hasVerification && this.password.length > 0 && this.hasLocation && !this.submitting && !this.locating);
  }

  createFaultCascadeRange(): TextCascadePickerRangeContent[] {
    const range: TextCascadePickerRangeContent[] = [];
    for (let typeIndex = 0; typeIndex < FAULT_TYPE_VALUES.length; typeIndex++) {
      const type = FAULT_TYPE_VALUES[typeIndex] as FaultType;
      const options = FaultReportService.getFaultSubtypeOptions(type);
      const children: TextCascadePickerRangeContent[] = [];
      for (let optionIndex = 0; optionIndex < options.length; optionIndex++) {
        const child: TextCascadePickerRangeContent = {
          text: options[optionIndex].label
        };
        children.push(child);
      }

      const item: TextCascadePickerRangeContent = {
        text: FaultReportService.formatFaultType(type),
        children
      };
      range.push(item);
    }

    return range;
  }

  getFaultTypeIndex(): number {
    return this.indexOfPickerValue(FAULT_TYPE_VALUES, this.faultType);
  }

  getFaultSubtypeIndex(): number {
    const options = FaultReportService.getFaultSubtypeOptions(this.faultType as FaultType);
    for (let index = 0; index < options.length; index++) {
      if (`${options[index].subtype}` === this.faultSubtype) {
        return index;
      }
    }

    return 0;
  }

  getSeverityIndex(): number {
    return this.indexOfPickerValue(SEVERITY_VALUES, this.severity);
  }

  isFaultTypeSelectionReady(): boolean {
    return FaultReportService.formatFaultTypeSelection(this.faultType as FaultType, this.faultSubtype as FaultSubtype) !==
      '请选择故障类型';
  }

  showFaultTypePicker(): void {
    if (this.submitting || this.submitted) {
      return;
    }

    const previousFaultType = this.faultType;
    const previousFaultSubtype = this.faultSubtype;
    this.getUIContext().showTextPickerDialog({
      range: this.createFaultCascadeRange(),
      selected: [this.getFaultTypeIndex(), this.getFaultSubtypeIndex()],
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
        this.applyFaultCascadeResult(value);
      },
      onChange: (value: TextPickerResult) => {
        this.applyFaultCascadeResult(value);
      },
      onCancel: () => {
        this.faultType = previousFaultType;
        this.faultSubtype = previousFaultSubtype;
      }
    });
  }

  showSeverityPicker(): void {
    if (this.submitting || this.submitted) {
      return;
    }

    const previousSeverity = this.severity;
    this.getUIContext().showTextPickerDialog({
      range: SEVERITY_LABELS,
      selected: this.getSeverityIndex(),
      canLoop: false,
      defaultPickerItemHeight: 38,
      selectedTextStyle: {
        color: this.severity.length > 0 ? this.getSeverityTone(this.severity as FaultSeverity) : AppColors.Primary,
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
        this.applySeverityResult(value);
      },
      onChange: (value: TextPickerResult) => {
        this.applySeverityResult(value);
      },
      onScrollStop: (value: TextPickerResult) => {
        this.applySeverityResult(value);
      },
      onCancel: () => {
        this.severity = previousSeverity;
      }
    });
  }

  applyFaultCascadeResult(result: TextPickerResult): void {
    const selection = this.resolveFaultCascadeValue(result.value);
    if (selection !== undefined) {
      this.applyFaultTypeSelection(selection);
      return;
    }

    this.applyFaultCascadeIndex(result.index);
  }

  applyFaultCascadeIndex(index: number | number[]): void {
    if (this.submitting || this.submitted) {
      return;
    }

    const indices = this.normalizeMultiPickerIndex(index);
    const typeIndex = this.normalizePickerIndex(indices[0], FAULT_TYPE_VALUES.length);
    const type = FAULT_TYPE_VALUES[typeIndex] as FaultType;
    const options = FaultReportService.getFaultSubtypeOptions(type);
    const subtypeIndex = this.normalizePickerIndex(indices[1], options.length);
    this.faultType = `${type}`;
    if (options.length > 0) {
      this.faultSubtype = `${options[subtypeIndex].subtype}`;
    } else {
      this.faultSubtype = `${FaultReportService.getDefaultFaultSubtype(type)}`;
    }
    this.markFormChanged();
  }

  applyFaultTypeSelection(selection: FaultTypeSelection): void {
    if (this.submitting || this.submitted) {
      return;
    }

    this.faultType = `${selection.faultType}`;
    this.faultSubtype = `${selection.faultSubtype}`;
    this.markFormChanged();
  }

  resolveFaultCascadeValue(value: string | string[]): FaultTypeSelection | undefined {
    if (typeof value === 'string') {
      return this.resolveFaultCascadeText(value);
    }

    if (value.length >= 2) {
      return FaultReportService.resolveFaultTypeSelection(value[0], value[1]);
    }

    if (value.length === 1) {
      return this.resolveFaultCascadeText(value[0]);
    }

    return undefined;
  }

  resolveFaultCascadeText(value: string): FaultTypeSelection | undefined {
    const parts = value.split('/');
    if (parts.length < 2) {
      return undefined;
    }

    return FaultReportService.resolveFaultTypeSelection(parts[0], parts[1]);
  }

  applySeverityResult(result: TextPickerResult): void {
    const severity = FaultReportService.resolveSeveritySelection(this.normalizeSinglePickerLabel(result.value));
    if (severity !== undefined) {
      this.severity = `${severity}`;
      this.markFormChanged();
      return;
    }

    this.applySeverityIndex(this.normalizeSinglePickerIndex(result.index));
  }

  applySeverityIndex(index: number): void {
    if (this.submitting || this.submitted) {
      return;
    }

    this.severity = SEVERITY_VALUES[this.normalizePickerIndex(index, SEVERITY_VALUES.length)];
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

  normalizeSinglePickerLabel(value: string | string[]): string {
    if (typeof value === 'string') {
      return value;
    }

    if (value.length === 0) {
      return '';
    }

    return value[0];
  }

  normalizeMultiPickerIndex(index: number | number[]): number[] {
    if (typeof index === 'number') {
      return [index, 0];
    }

    if (index.length === 0) {
      return [0, 0];
    }

    if (index.length === 1) {
      return [index[0], 0];
    }

    return [index[0], index[1]];
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

  getSeverityTone(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return AppColors.Danger;
      case FaultSeverity.Severe:
        return AppColors.Warning;
      case FaultSeverity.General:
        return AppColors.Primary;
      case FaultSeverity.Minor:
        return AppColors.Success;
      default:
        return AppColors.TextSecondary;
    }
  }

  markFormChanged(): void {
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
  }

  handleBackAction(): void {
    if (this.submitted || !this.hasVerification) {
      this.backToVerificationReport();
      return;
    }

    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.showLeaveConfirmDialog();
  }

  async showLeaveConfirmDialog(): Promise<void> {
    if (this.showingLeaveDialog || this.submitted || !this.hasVerification) {
      return;
    }

    this.showingLeaveDialog = true;
    try {
      const response = await this.getUIContext().getPromptAction().showDialog({
        title: '放弃报修报告？',
        message: '当前报修报告尚未提交，返回将放弃本次异常核验与报修报告填写',
        buttons: [
          {
            text: '继续填写',
            color: AppColors.Primary,
            primary: true
          },
          {
            text: '放弃返回',
            color: AppColors.Danger
          }
        ]
      });
      if (response.index === 1) {
        VerificationReportFlowStore.markFaultReportDiscarded();
        this.backToVerificationReport();
      }
    } catch (err) {
      this.message = '当前报修报告尚未提交，请先提交或确认放弃';
      this.messageTone = UiFeedbackTone.Warning;
    } finally {
      this.showingLeaveDialog = false;
    }
  }

  showOccurredAtPicker(): void {
    if (this.submitting || this.submitted) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.occurredAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.occurredAt = this.formatDateTime(value);
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

  backToVerificationReport(): void {
    AppNavigator.backOrReplace(this.getUIContext(), AppRoutes.VerificationReportPage, {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
