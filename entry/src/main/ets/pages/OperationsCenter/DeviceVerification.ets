import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { FaultSeverity, FaultType } from '../../models/FaultModels';
import { PermissionCode } from '../../models/PermissionModels';
import { VerificationResult } from '../../models/VerificationModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceService } from '../../services/DeviceService';
import { DeviceVerificationService } from '../../services/DeviceVerificationService';
import { FaultReportService } from '../../services/FaultReportService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct DeviceVerification {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State verificationResult: string = '';
  @State description: string = '';
  @State remark: string = '';
  @State faultType: string = '';
  @State severity: string = '';
  @State occurredAt: string = '';
  @State faultDescription: string = '';
  @State sceneCondition: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State normalizedDeviceCode: string = '-';
  @State latestReportNo: string = '-';
  @State submitting: boolean = false;
  @State submitted: boolean = false;

  aboutToAppear(): void {
    AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OpsDeviceVerify);
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.VerificationForm()
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
    this.backToWorkbench();
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
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .onClick(() => {
        this.backToWorkbench();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 24,
      right: 24
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 6 }) {
      Text('设备核验与报修')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('记录设备现场状态，异常时同步进入维修流程')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: 0,
      bottom: 2
    })
  }

  @Builder
  VerificationForm() {
    Column({ space: 16 }) {
      this.DeviceCodeField()
      this.ResultSelector()
      this.DescriptionField()
      this.RemarkField()
      if (this.requiresFaultReport()) {
        this.FaultReportSection()
      }
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), $r('sys.symbol.checkmark_circle'), !this.submitting && !this.submitted,
        () => {
          this.submitVerification();
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
        placeholder: '输入设备编号',
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
        this.ResultOption(VerificationResult.Unavailable, $r('sys.symbol.xmark_circle'))
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

        Text(DeviceVerificationService.formatVerificationResult(result))
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
  DescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('现场描述')

      TextArea({
        placeholder: '填写现场状态、异常现象或核验依据',
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
  RemarkField() {
    Column({ space: 10 }) {
      this.FieldTitle('备注')

      TextArea({
        placeholder: '填写补充说明',
        text: this.remark
      })
        .height(86)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(300)
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
          this.remark = value;
          this.markFormChanged();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FaultReportSection() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_message'))
          .fontSize(20)
          .fontColor([AppColors.Danger])

        Text('报修信息')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.FaultTypeSelector()
      this.SeveritySelector()
      this.OccurredAtField()
      this.FaultDescriptionField()
      this.SceneConditionField()
    }
    .width('100%')
    .padding({
      left: 14,
      right: 14,
      top: 14,
      bottom: 14
    })
    .backgroundColor(AppColors.FieldBackground)
    .borderRadius(18)
    .border({
      width: 1,
      color: AppColors.Border
    })
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
    .backgroundColor(this.faultType === `${type}` ? AppColors.Primary : AppColors.Surface)
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
    .backgroundColor(this.severity === `${severity}` ? this.getSeverityTone(severity) : AppColors.Surface)
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
      this.FieldTitle('发生时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.occurredAt.length > 0 ? this.occurredAt : '选择发生时间')
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
      .backgroundColor(AppColors.Surface)
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
      this.FieldTitle('故障描述')

      TextArea({
        placeholder: '填写故障现象、影响范围和发现过程',
        text: this.faultDescription
      })
        .height(128)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(800)
        .backgroundColor(AppColors.Surface)
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
  SceneConditionField() {
    Column({ space: 10 }) {
      this.FieldTitle('现场情况')

      TextArea({
        placeholder: '填写现场环境、临时处理措施或补充说明',
        text: this.sceneCondition
      })
        .height(96)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(500)
        .backgroundColor(AppColors.Surface)
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
          this.sceneCondition = value;
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
        StatusInfoRow({
          label: '核验结果',
          value: this.getVerificationResultStatusText(),
          tone: this.getSelectedResultTone()
        })
        this.CardDivider()
        StatusInfoRow({
          label: '联动报修',
          value: this.getFaultReportStatusText(),
          tone: this.getFaultReportStatusTone()
        })
        this.CardDivider()
        StatusInfoRow({
          label: '报修编号',
          value: this.latestReportNo,
          tone: AppColors.TextSecondary
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
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

    this.submitting = true;
    try {
      if (this.requiresFaultReport()) {
        await this.submitVerificationWithFaultReport();
      } else {
        await this.submitNormalVerification();
      }
    } finally {
      this.submitting = false;
    }
  }

  async submitNormalVerification(): Promise<void> {
    const response = await DeviceVerificationService.submitVerificationRemoteFirst({
      deviceCode: this.deviceCode,
      result: this.verificationResult as VerificationResult,
      description: this.description,
      remark: this.remark
    });
    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '核验提交失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    const recordId = response.data ? response.data.id : '';
    if (DeviceVerificationService.isOfflineSyncQueuedResponse(response)) {
      this.message = recordId.length > 0 ?
        `核验记录已保存至本地同步队列，恢复在线并同步成功后将提交至后端处理：${recordId}` :
        '核验记录已保存至本地同步队列，恢复在线并同步成功后将提交至后端处理';
    } else {
      this.message = recordId.length > 0 ? `核验记录已提交：${recordId}` : '核验记录已提交';
    }
    this.messageTone = AppColors.Success;
    this.submitted = true;
  }

  async submitVerificationWithFaultReport(): Promise<void> {
    if (!SessionStore.hasPermission(PermissionCode.OpsFaultReportCreate)) {
      this.message = '当前账号无权提交报修信息，无法提交异常核验';
      this.messageTone = AppColors.Danger;
      return;
    }

    const response = await DeviceVerificationService.submitVerificationWithFaultReportRemoteFirst({
      verification: {
        deviceCode: this.deviceCode,
        result: this.verificationResult as VerificationResult,
        description: this.description,
        remark: this.remark
      },
      faultReport: {
        deviceCode: this.deviceCode,
        faultType: this.faultType as FaultType,
        severity: this.severity as FaultSeverity,
        occurredAt: this.occurredAt,
        description: this.faultDescription,
        sceneCondition: this.sceneCondition
      }
    });
    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '设备核验与报修提交失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    const reportNo = response.data ? response.data.faultReport.reportNo : '';
    this.latestReportNo = reportNo.length > 0 ? reportNo : '-';
    this.message = DeviceVerificationService.isOfflineSyncQueuedFaultReportResponse(response) ?
      '设备核验与报修已保存至本地同步队列，恢复在线并同步成功后将提交至后端处理' : '设备核验与报修已提交';
    this.messageTone = AppColors.Success;
    this.submitted = true;
  }

  getVerificationResultStatusText(): string {
    return this.verificationResult.length === 0 ? '-' :
      DeviceVerificationService.formatVerificationResult(this.verificationResult as VerificationResult);
  }

  getSelectedResultTone(): string {
    return this.verificationResult.length === 0 ? AppColors.TextSecondary : this.getResultTone(this.verificationResult as VerificationResult);
  }

  getResultTone(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return AppColors.Success;
      case VerificationResult.Abnormal:
        return AppColors.Danger;
      case VerificationResult.Unavailable:
        return AppColors.TextSecondary;
      default:
        return AppColors.TextSecondary;
    }
  }

  requiresFaultReport(): boolean {
    return this.verificationResult === `${VerificationResult.Abnormal}` ||
      this.verificationResult === `${VerificationResult.Unavailable}`;
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.submitted) {
      return '已提交';
    }

    return this.requiresFaultReport() ? '提交核验与报修' : '提交核验';
  }

  getFaultReportStatusText(): string {
    if (!this.requiresFaultReport()) {
      return '不需要';
    }

    if (this.submitted) {
      return '已提交';
    }

    return '需填写';
  }

  getFaultReportStatusTone(): string {
    if (!this.requiresFaultReport()) {
      return AppColors.TextSecondary;
    }

    return this.submitted ? AppColors.Success : AppColors.Warning;
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
    this.messageTone = AppColors.Danger;
    this.latestReportNo = '-';
    this.submitted = false;
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

  backToWorkbench(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
