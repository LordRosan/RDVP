import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { FaultSeverity, FaultType } from '../../models/operations/FaultModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { VerificationResult } from '../../models/operations/DeviceVerificationAndFaultReportModels';
import { DeviceService } from '../../services/archive/DeviceService';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { DeviceVerificationAndFaultReportService } from '../../services/operations/DeviceVerificationAndFaultReportService';
import { FaultReportService } from '../../services/operations/FaultReportService';
import { AuthService } from '../../services/identity/AuthService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { AppNavigator } from '../../utils/AppNavigator';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

@Entry
@Component
struct DeviceVerificationAndFaultReport {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State verificationResult: string = '';
  @State description: string = '';
  @State verifiedAt: string = '';
  @State faultType: string = '';
  @State severity: string = '';
  @State occurredAt: string = '';
  @State faultDescription: string = '';
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

      Text('Verification and Fault Report')
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
        this.ResultSelector()
        if (this.isNormalVerification()) {
          this.VerifiedAtField()
          this.DescriptionField()
        }
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

      if (this.requiresFaultReport()) {
        this.FaultReportSection()
      }

      this.PasswordSection()
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), this.getSubmitIcon(),!this.submitting && !this.submitted,
        () => {
          this.submitVerification();
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
  ResultSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('核验结果')

      Row({ space: 10 }) {
        this.ResultOption(VerificationResult.Normal, $r('sys.symbol.checkmark_circle'))
        this.ResultOption(VerificationResult.Abnormal, $r('sys.symbol.exclamationmark_shield_fill'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultOption(result: VerificationResult, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.verificationResult === `${result}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(DeviceVerificationAndFaultReportService.formatVerificationResult(result))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.verificationResult === `${result}` ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.verificationResult === `${result}` ? this.getResultTone(result) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.verificationResult === `${result}` ? this.getResultTone(result) : AppColors.Border
    })
    .enabled(!this.submitting && !this.submitted)
    .onClick(() => {
      this.verificationResult = `${result}`;
      this.markFormChanged();
    })
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
  FaultReportSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '报修信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.FaultTypeSelector()
        this.SeveritySelector()
        this.OccurredAtField()
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
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FaultTypeSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('故障类型')

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          Column() {
            this.FaultTypeOption(FaultType.OperationAbnormal, $r('sys.symbol.exclamationmark_message'))
          }
          .layoutWeight(1)

          Column() {
            this.FaultTypeOption(FaultType.HardwareDamage, $r('sys.symbol.wrench_and_screwdriver'))
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          Column() {
            this.FaultTypeOption(FaultType.CommunicationFault, $r('sys.symbol.wifi_badge_exclamationmark'))
          }
          .layoutWeight(1)

          Column() {
            this.FaultTypeOption(FaultType.LogicFault, $r('sys.symbol.gearshape'))
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          Column() {
            this.FaultTypeOption(FaultType.EnergyFault, $r('sys.symbol.bolt'))
          }
          .layoutWeight(1)

          Column() {
            this.FaultTypeOption(FaultType.ExternalFactor, $r('sys.symbol.geologic_hazard'))
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Blank()
            .layoutWeight(1)

          Column() {
            this.FaultTypeOption(FaultType.Other, $r('sys.symbol.text_clipboard'))
          }
          .width('48%')

          Blank()
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FaultTypeOption(type: FaultType, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.faultType === `${type}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(FaultReportService.formatFaultType(type))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.faultType === `${type}` ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .width('100%')
    .backgroundColor(this.faultType === `${type}` ? AppColors.Primary : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.faultType === `${type}` ? AppColors.Primary : AppColors.Border
    })
    .enabled(!this.submitting && !this.submitted)
    .onClick(() => {
      this.faultType = `${type}`;
      this.markFormChanged();
    })
  }

  @Builder
  SeveritySelector() {
    Column({ space: 10 }) {
      this.FieldTitle('故障等级')

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.SeverityOption(FaultSeverity.Emergency, $r('sys.symbol.exclamationmark_triangle_fill'))
          this.SeverityOption(FaultSeverity.Severe, $r('sys.symbol.exclamationmark_circle'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          this.SeverityOption(FaultSeverity.General, $r('sys.symbol.exclamationmark_message'))
          this.SeverityOption(FaultSeverity.Minor, $r('sys.symbol.checkmark_circle'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SeverityOption(severity: FaultSeverity, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.severity === `${severity}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(FaultReportService.formatSeverity(severity))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.severity === `${severity}` ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.severity === `${severity}` ? this.getSeverityTone(severity) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.severity === `${severity}` ? this.getSeverityTone(severity) : AppColors.Border
    })
    .enabled(!this.submitting && !this.submitted)
    .onClick(() => {
      this.severity = `${severity}`;
      this.markFormChanged();
    })
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
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
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

  async submitVerification(): Promise<void> {
    if (this.submitting || this.submitted) {
      return;
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    const validation = this.validateCurrentForm();
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

      if (this.requiresFaultReport()) {
        await this.submitVerificationAndFaultReport();
      } else {
        await this.submitNormalVerification();
      }
    } finally {
      this.submitting = false;
    }
  }

  async submitNormalVerification(): Promise<void> {
    const response = await DeviceVerificationAndFaultReportService.submitVerificationRemoteFirst({
      deviceCode: this.deviceCode,
      result: this.verificationResult as VerificationResult,
      description: this.description,
      verifiedAt: this.verifiedAt
    });
    if (!response.success) {
      const error = response.error;
      this.message = UiFeedbackService.operationError(error, '提交');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.message = UiFeedbackService.operationSuccess('提交');
    this.messageTone = UiFeedbackTone.Success;
    this.password = '';
    this.submitted = true;
  }

  async submitVerificationAndFaultReport(): Promise<void> {
    if (!SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceFaultReportSubmit)) {
      this.message = UiFeedbackService.operationUnavailable('提交');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    const response = await DeviceVerificationAndFaultReportService.submitVerificationAndFaultReportRemoteFirst({
      verification: {
        deviceCode: this.deviceCode,
        result: this.verificationResult as VerificationResult,
        description: '',
        verifiedAt: ''
      },
      faultReport: {
        deviceCode: this.deviceCode,
        faultType: this.faultType as FaultType,
        severity: this.severity as FaultSeverity,
        occurredAt: this.occurredAt,
        description: this.faultDescription,
        sceneCondition: ''
      }
    });
    if (!response.success) {
      const error = response.error;
      this.message = UiFeedbackService.operationError(error, '提交');
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.message = UiFeedbackService.operationSuccess('提交');
    this.messageTone = UiFeedbackTone.Success;
    this.password = '';
    this.submitted = true;
  }

  getVerificationResultStatusText(): string {
    return this.verificationResult.length === 0 ? '-' :
      DeviceVerificationAndFaultReportService.formatVerificationResult(this.verificationResult as VerificationResult);
  }

  getSelectedResultTone(): string {
    return this.verificationResult.length === 0 ? AppColors.TextSecondary :
      this.getResultTone(this.verificationResult as VerificationResult);
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

  requiresFaultReport(): boolean {
    return this.verificationResult === `${VerificationResult.Abnormal}`;
  }

  isNormalVerification(): boolean {
    return this.verificationResult === `${VerificationResult.Normal}`;
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.submitted) {
      return '已提交';
    }

    return '提交报告';
  }

  getSubmitIcon(): Resource {
    return $r('sys.symbol.checkmark_circle');
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
    this.submitted = false;
  }

  validateCurrentForm() {
    if (this.requiresFaultReport()) {
      return DeviceVerificationAndFaultReportService.validateVerificationAndFaultReportForm({
        verification: {
          deviceCode: this.deviceCode,
          result: this.verificationResult as VerificationResult,
          description: '',
          verifiedAt: '',
          remark: ''
        },
        faultReport: {
          deviceCode: this.deviceCode,
          faultType: this.faultType as FaultType,
          severity: this.severity as FaultSeverity,
          occurredAt: this.occurredAt,
          description: this.faultDescription,
          sceneCondition: ''
        }
      });
    }

    return DeviceVerificationAndFaultReportService.validateVerificationForm({
      deviceCode: this.deviceCode,
      result: this.verificationResult as VerificationResult,
      description: this.description,
      verifiedAt: this.verifiedAt,
      remark: ''
    });
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
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/OperationsCenter/OperationsCenter', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
