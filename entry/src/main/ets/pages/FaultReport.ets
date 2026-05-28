import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import { FaultSeverity, FaultType } from '../models/FaultModels';
import { DeviceService } from '../services/DeviceService';
import { FaultReportService } from '../services/FaultReportService';

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
  @State faultType: FaultType = FaultType.OperationAbnormal;
  @State severity: FaultSeverity = FaultSeverity.General;
  @State occurredAt: string = '';
  @State description: string = '';
  @State sceneCondition: string = '';
  @State message: string = '';
  @State normalizedDeviceCode: string = '-';
  private faultInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '故障分类说明',
      sections: FAULT_REPORT_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

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
    .backgroundColor('#F2F5F7')
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
          .fontColor(['#111827'])
      }
      .width(44)
      .height(44)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
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
    .backgroundColor('#F2F5F7')
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text('故障报告')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('登记设备故障信息')
          .fontSize(15)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_message'))
          .fontSize(32)
          .fontColor(['#111827'])
      }
      .width(58)
      .height(58)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
      })
      .onClick(() => {
        this.showFaultReportInfoDialog();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
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
      this.ActionButton('提交报告', $r('sys.symbol.exclamationmark_message'), () => {
        this.submitFaultReport();
      })
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor('#FFFFFF')
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.message = '';
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
          .fontColor([this.faultType === type ? '#FFFFFF' : '#111827'])

        Text(FaultReportService.formatFaultType(type))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.faultType === type ? '#FFFFFF' : '#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .width('100%')
    .backgroundColor(this.faultType === type ? '#2F6FED' : '#F7F9FC')
    .border({
      width: 1,
      color: this.faultType === type ? '#2F6FED' : '#D6DAE1'
    })
    .onClick(() => {
      this.faultType = type;
      this.message = '';
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
          .fontColor([this.severity === severity ? '#FFFFFF' : '#111827'])

        Text(FaultReportService.formatSeverity(severity))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.severity === severity ? '#FFFFFF' : '#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.severity === severity ? this.getSeverityTone(severity) : '#F7F9FC')
    .border({
      width: 1,
      color: this.severity === severity ? this.getSeverityTone(severity) : '#D6DAE1'
    })
    .onClick(() => {
      this.severity = severity;
      this.message = '';
    })
  }

  @Builder
  OccurredAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('发生时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor(['#111827'])

        Text(this.occurredAt.length > 0 ? this.occurredAt : '选择发生时间')
          .fontSize(16)
          .fontColor(this.occurredAt.length > 0 ? '#111827' : '#9CA3AF')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor(['#6B7280'])
      }
        .height(56)
        .width('100%')
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onClick(() => {
          this.showOccurredAtPicker();
          this.message = '';
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.description = value;
          this.message = '';
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.sceneCondition = value;
          this.message = '';
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
      .fontColor('#111827')
      .maxLines(1)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor('#D9480F')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor(['#FFFFFF'])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor('#2F6FED')
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
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.StatusRow('标准编号', this.normalizedDeviceCode, '#374151')
        this.CardDivider()
        this.StatusRow('故障类型', FaultReportService.formatFaultType(this.faultType), '#374151')
        this.CardDivider()
        this.StatusRow('故障等级', FaultReportService.formatSeverity(this.severity), this.getSeverityTone(this.severity))
        this.CardDivider()
        this.StatusRow('服务状态', '未连接', '#D9480F')
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor('#E5E7EB')
      .margin({
        left: 18,
        right: 18
      })
  }

  @Builder
  StatusRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#111827')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(15)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(54)
    .padding({
      left: 18,
      right: 18
    })
    .width('100%')
  }

  submitFaultReport(): void {
    const response = FaultReportService.submitFaultReport({
      deviceCode: this.deviceCode,
      faultType: this.faultType,
      severity: this.severity,
      occurredAt: this.occurredAt,
      description: this.description,
      sceneCondition: this.sceneCondition
    });

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '故障报告提交失败';
    }
  }

  getSeverityTone(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return '#D9480F';
      case FaultSeverity.Severe:
        return '#E67700';
      case FaultSeverity.General:
        return '#2F6FED';
      case FaultSeverity.Minor:
        return '#087F5B';
      default:
        return '#374151';
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
        this.message = '';
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
    return `${value.getFullYear()}-${this.pad2(value.getMonth() + 1)}-${this.pad2(value.getDate())} ${this.pad2(value.getHours())}:${this.pad2(value.getMinutes())}`;
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

      router.replaceUrl({ url: 'pages/Index' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
