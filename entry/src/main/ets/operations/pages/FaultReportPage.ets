import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { FaultSeverity, FaultType } from '../models/FaultModels';
import {
  VerificationReportForm,
  AbnormalVerificationSubmissionForm,
  VerificationResult
} from '../models/VerificationReportModels';
import { PermissionCode } from '../../user/models/PermissionModels';
import { DeviceService } from '../../archive/services/DeviceService';
import { FaultReportService } from '../services/FaultReportService';
import { VerificationReportService } from '../services/VerificationReportService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { AuthService } from '../../user/services/AuthService';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { AppRoutes } from '../../shared/navigation/AppRoutes';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';
import { VerificationReportFlowStore } from '../stores/VerificationReportFlowStore';

@Entry
@Component
struct FaultReportPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State faultType: string = '';
  @State severity: string = '';
  @State occurredAt: string = '';
  @State faultDescription: string = '';
  @State password: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State submitting: boolean = false;
  @State submitted: boolean = false;
  @State hasVerification: boolean = false;
  private verification: VerificationReportForm = {
    deviceCode: '',
    result: VerificationResult.Abnormal,
    description: '',
    verifiedAt: '',
    remark: ''
  };

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
            this.VerificationSummarySection()
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
  VerificationSummarySection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '核验信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.ReadOnlyField('设备编号', this.deviceCode)
        this.ReadOnlyField('核验结果', VerificationReportService.formatVerificationResult(VerificationResult.Abnormal))
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
  FaultReportFormBody() {
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
        .enabled(false)
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
      stateEffect: this.submitted || (this.hasVerification && this.password.length > 0 && !this.submitting)
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
    .backgroundColor(this.submitted || (this.hasVerification && this.password.length > 0 && !this.submitting) ?
      AppColors.Primary : AppColors.Disabled)
    .enabled(this.submitted || (this.hasVerification && this.password.length > 0 && !this.submitting))
    .onClick(() => {
      this.handleSubmitAction();
    })
  }

  loadVerificationContext(): void {
    const pending = VerificationReportFlowStore.getPendingAbnormalVerification();
    if (pending === undefined || pending.result !== VerificationResult.Abnormal) {
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
      verification: {
        deviceCode: this.verification.deviceCode,
        result: VerificationResult.Abnormal,
        description: this.verification.description,
        verifiedAt: this.verification.verifiedAt,
        remark: this.verification.remark
      },
      faultReport: {
        deviceCode: this.verification.deviceCode,
        faultType: this.faultType as FaultType,
        severity: this.severity as FaultSeverity,
        occurredAt: this.occurredAt,
        description: this.faultDescription,
        sceneCondition: ''
      }
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

    this.showDiscardConfirmation();
  }

  showDiscardConfirmation(): void {
    AlertDialog.show({
      title: '放弃报修报告填写？',
      message: '返回将放弃本次异常核验与报修报告填写。',
      autoCancel: false,
      primaryButton: {
        value: '继续填写',
        action: () => {
        }
      },
      secondaryButton: {
        value: '放弃返回',
        action: () => {
          VerificationReportFlowStore.markFaultReportDiscarded();
          this.backToVerificationReport();
        }
      }
    });
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
