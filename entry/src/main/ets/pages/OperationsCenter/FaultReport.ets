import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { FaultSeverity, FaultType } from '../../models/FaultModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceService } from '../../services/DeviceService';
import { FaultReportService } from '../../services/FaultReportService';
import { OperationsFlowStore } from '../../stores/OperationsFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const FAULT_REPORT_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '故障类型',
    items: [
      {
        label: FaultReportService.formatFaultType(FaultType.OperationAbnormal),
        description: FaultReportService.formatFaultTypeDescription(FaultType.OperationAbnormal)
      },
      {
        label: FaultReportService.formatFaultType(FaultType.HardwareDamage),
        description: FaultReportService.formatFaultTypeDescription(FaultType.HardwareDamage)
      },
      {
        label: FaultReportService.formatFaultType(FaultType.CommunicationFault),
        description: FaultReportService.formatFaultTypeDescription(FaultType.CommunicationFault)
      },
      {
        label: FaultReportService.formatFaultType(FaultType.LogicFault),
        description: FaultReportService.formatFaultTypeDescription(FaultType.LogicFault)
      },
      {
        label: FaultReportService.formatFaultType(FaultType.EnergyFault),
        description: FaultReportService.formatFaultTypeDescription(FaultType.EnergyFault)
      },
      {
        label: FaultReportService.formatFaultType(FaultType.ExternalFactor),
        description: FaultReportService.formatFaultTypeDescription(FaultType.ExternalFactor)
      },
      {
        label: FaultReportService.formatFaultType(FaultType.Other),
        description: FaultReportService.formatFaultTypeDescription(FaultType.Other)
      }
    ]
  },
  {
    title: '故障等级',
    items: [
      {
        label: FaultReportService.formatSeverity(FaultSeverity.Emergency),
        description: FaultReportService.formatSeverityDescription(FaultSeverity.Emergency)
      },
      {
        label: FaultReportService.formatSeverity(FaultSeverity.Severe),
        description: FaultReportService.formatSeverityDescription(FaultSeverity.Severe)
      },
      {
        label: FaultReportService.formatSeverity(FaultSeverity.General),
        description: FaultReportService.formatSeverityDescription(FaultSeverity.General)
      },
      {
        label: FaultReportService.formatSeverity(FaultSeverity.Minor),
        description: FaultReportService.formatSeverityDescription(FaultSeverity.Minor)
      }
    ]
  }
];

@Entry
@Component
struct FaultReport {
  @State deviceCode: string = '';
  @State faultType: string = '';
  @State severity: string = '';
  @State occurredAt: string = '';
  @State description: string = '';
  @State sceneCondition: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State normalizedDeviceCode: string = '-';
  @State latestReportNo: string = '-';
  @State submitting: boolean = false;
  @State submitted: boolean = false;
  private faultInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '故障分类说明',
      sections: FAULT_REPORT_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OpsFaultReportCreate)) {
      return;
    }

    this.applyPrefill();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.FaultForm()
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
      Row({ space: 6 }) {
        Text('故障报告')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showFaultReportInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('登记设备故障信息')
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
  FaultForm() {
    Column({ space: 16 }) {
      this.DeviceCodeField()
      this.FaultTypeSelector()
      this.SeveritySelector()
      this.OccurredAtField()
      this.DescriptionField()
      this.SceneConditionField()
      this.MessageText()
      this.ActionButton(this.submitting ? '提交中' : '提交报告', $r('sys.symbol.exclamationmark_message'), () => {
        this.submitFaultReport();
      }, !this.submitting && !this.submitted)
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
          .fontColor([this.faultType === `${type}` ? AppColors.Surface : AppColors.TextPrimary])

        Text(FaultReportService.formatFaultType(type))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.faultType === `${type}` ? AppColors.Surface : AppColors.TextPrimary)
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
          .fontColor([this.severity === `${severity}` ? AppColors.Surface : AppColors.TextPrimary])

        Text(FaultReportService.formatSeverity(severity))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.severity === `${severity}` ? AppColors.Surface : AppColors.TextPrimary)
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
        this.showOccurredAtPicker();
        this.markFormChanged();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('故障描述')

      TextArea({
        placeholder: '填写故障现象、影响范围和发现过程',
        text: this.description
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
        .onChange((value: string) => {
          this.description = value;
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
  ActionButton(label: string, icon: Resource, action: () => void, enabled: boolean) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.Surface])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.Surface)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(AppColors.Primary)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  @Builder
  InfoButton(action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor([AppColors.TextPrimary])
    }
    .width(28)
    .height(28)
    .backgroundColor(AppColors.Transparent)
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
        StatusInfoRow({ label: '报告编号', value: this.latestReportNo, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '故障类型',
          value: this.getFaultTypeStatusText(),
          tone: AppColors.TextSecondary
        })
        this.CardDivider()
        StatusInfoRow({
          label: '故障等级',
          value: this.getSeverityStatusText(),
          tone: this.getSelectedSeverityTone()
        })
        this.CardDivider()
        StatusInfoRow({
          label: '服务状态',
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

  async submitFaultReport(): Promise<void> {
    if (this.submitting || this.submitted) {
      return;
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    this.submitting = true;
    try {
      const response = await FaultReportService.submitFaultReportRemoteFirst({
        deviceCode: this.deviceCode,
        faultType: this.faultType as FaultType,
        severity: this.severity as FaultSeverity,
        occurredAt: this.occurredAt,
        description: this.description,
        sceneCondition: this.sceneCondition
      });

      if (!response.success) {
        const error = response.error;
        this.message = error ? error.message : '故障报告提交失败';
        this.messageTone = AppColors.Danger;
        return;
      }

      const reportNo = response.data ? response.data.reportNo : '';
      this.latestReportNo = reportNo.length > 0 ? reportNo : '-';
      this.submitted = true;
      this.message = '故障报告已提交';
      this.messageTone = AppColors.Success;
    } catch (err) {
      this.message = '故障报告提交失败，请稍后重试';
      this.messageTone = AppColors.Danger;
    } finally {
      this.submitting = false;
    }
  }

  markFormChanged(): void {
    this.message = '';
    this.messageTone = AppColors.Danger;
    this.latestReportNo = '-';
    this.submitted = false;
  }

  applyPrefill(): void {
    const prefill = OperationsFlowStore.consumeFaultReportPrefill();
    if (prefill === undefined) {
      return;
    }

    this.deviceCode = prefill.deviceCode;
    this.description = prefill.description;
    this.sceneCondition = prefill.sceneCondition;
    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(prefill.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }
  }

  getFaultTypeStatusText(): string {
    return this.faultType.length === 0 ? '-' : FaultReportService.formatFaultType(this.faultType as FaultType);
  }

  getSeverityStatusText(): string {
    return this.severity.length === 0 ? '-' : FaultReportService.formatSeverity(this.severity as FaultSeverity);
  }

  getSelectedSeverityTone(): string {
    return this.severity.length === 0 ? AppColors.TextSecondary : this.getSeverityTone(this.severity as FaultSeverity);
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

  showFaultReportInfoDialog(): void {
    this.faultInfoDialogController.open();
  }

  showOccurredAtPicker(): void {
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
      this.message = '页面跳转失败';
    }
  }
}
