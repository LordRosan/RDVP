import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import { StatusInfoRow } from '../components/StatusInfoRow';
import {
  ReinspectionResult, ReinspectionTaskSummary
} from '../models/ReinspectionModels';
import { ApiClient } from '../services/ApiClient';
import { ReinspectionService } from '../services/ReinspectionService';
import { AuthGuard } from '../utils/AuthGuard';

const REINSPECTION_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '复检任务',
    items: [
      {
        label: '适用范围',
        description: '高等级故障维修后需要复检确认，防止设备在风险未消除前恢复正常状态'
      },
      {
        label: '复检结论',
        description: '复检通过后可进入关闭流程；复检不通过时应重新进入维修处理流程'
      }
    ]
  }
];

@Entry
@Component
struct ReinspectionTask {
  @State taskItems: ReinspectionTaskSummary[] = [];
  @State taskId: string = '';
  @State result: ReinspectionResult = ReinspectionResult.Passed;
  @State reinspectedAt: string = '';
  @State description: string = '';
  @State taskMessage: string = '';
  @State recordMessage: string = '';
  @State recordMessageTone: string = '#D9480F';
  @State refreshStatus: string = '未刷新';
  @State normalizedTaskId: string = '-';
  @State refreshing: boolean = false;
  @State submitting: boolean = false;
  private reinspectionInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '复检任务说明',
      sections: REINSPECTION_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requireAuthenticated(this.getUIContext())) {
      return;
    }

    this.refreshTasks();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.TaskListPanel()
          this.RecordForm()
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
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('复检任务')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.reinspectionInfoDialogController.open();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('确认高等级故障维修结果')
        .fontSize(15)
        .fontColor('#6B7280')
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
  TaskListPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('待复检任务')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
          .maxLines(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .backgroundColor('#2F6FED')
        .enabled(!this.refreshing && !this.submitting)
        .onClick(() => {
          this.refreshTasks();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.taskItems.length === 0) {
        this.EmptyTaskState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.taskItems, (item: ReinspectionTaskSummary) => {
            this.TaskItem(item)
          }, (item: ReinspectionTaskSummary) => item.id)
        }
        .width('100%')
      }

      this.TaskMessageText()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  EmptyTaskState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.doc_text_badge_checkmark'))
          .fontSize(36)
          .fontColor(['#2F6FED'])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor('#EEF4FF')

      Text('暂无待复检任务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 28,
      bottom: 28
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TaskItem(item: ReinspectionTaskSummary) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.doc_text_badge_checkmark'))
            .fontSize(23)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(ReinspectionService.getSeverityTone(item.severity))

        Column({ space: 4 }) {
          Text(item.deviceName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.taskNo)
            .fontSize(12)
            .fontColor('#6B7280')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(item.location)
          .fontSize(13)
          .fontColor('#374151')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(ReinspectionService.formatSeverity(item.severity))
          .fontSize(13)
          .fontColor(ReinspectionService.getSeverityTone(item.severity))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.text_clipboard'))
            .fontSize(18)
            .fontColor(['#FFFFFF'])

          Text('填写复检记录')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width('100%')
      }
      .height(46)
      .width('100%')
      .backgroundColor('#2F6FED')
      .onClick(() => {
        this.taskId = item.taskNo;
        this.normalizedTaskId = item.taskNo;
        this.recordMessage = '';
        this.recordMessageTone = '#D9480F';
      })
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
  }

  @Builder
  RecordForm() {
    Column({ space: 16 }) {
      this.FieldTitle('复检记录')
      this.TaskIdField()
      this.ResultSelector()
      this.ReinspectedAtField()
      this.DescriptionField()
      this.RecordMessageText()
      this.ActionButton(this.submitting ? '提交中' : '提交复检', $r('sys.symbol.checkmark_circle'), !this.submitting,
        () => {
          this.submitRecord();
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
  TaskIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('复检任务编号')

      TextInput({
        placeholder: '输入复检任务编号',
        text: this.taskId
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
          this.taskId = value;
          this.normalizedTaskId = value.trim().toUpperCase();
          if (this.normalizedTaskId.length === 0) {
            this.normalizedTaskId = '-';
          }
          this.recordMessage = '';
          this.recordMessageTone = '#D9480F';
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('复检结论')

      Row({ space: 10 }) {
        this.ResultOption(ReinspectionResult.Passed, $r('sys.symbol.checkmark_circle'))
        this.ResultOption(ReinspectionResult.Failed, $r('sys.symbol.xmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultOption(result: ReinspectionResult, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.result === result ? '#FFFFFF' : '#111827'])

        Text(ReinspectionService.formatResult(result))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.result === result ? '#FFFFFF' : '#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.result === result ? ReinspectionService.getResultTone(result) : '#F7F9FC')
    .border({
      width: 1,
      color: this.result === result ? ReinspectionService.getResultTone(result) : '#D6DAE1'
    })
    .onClick(() => {
      this.result = result;
      this.recordMessage = '';
      this.recordMessageTone = '#D9480F';
    })
  }

  @Builder
  ReinspectedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('复检时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor(['#111827'])

        Text(this.reinspectedAt.length > 0 ? this.reinspectedAt : '选择复检时间')
          .fontSize(16)
          .fontColor(this.reinspectedAt.length > 0 ? '#111827' : '#9CA3AF')
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
        this.showReinspectedAtPicker();
        this.recordMessage = '';
        this.recordMessageTone = '#D9480F';
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('复检说明')

      TextArea({
        placeholder: '填写复检依据、现场状态、验证结果和遗留风险',
        text: this.description
      })
        .height(132)
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
          this.recordMessage = '';
          this.recordMessageTone = '#D9480F';
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
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '标准任务号', value: this.normalizedTaskId, tone: '#374151' })
        this.CardDivider()
        StatusInfoRow({
          label: '复检结论',
          value: ReinspectionService.formatResult(this.result),
          tone: ReinspectionService.getResultTone(this.result)
        })
        this.CardDivider()
        StatusInfoRow({
          label: '刷新状态',
          value: this.taskMessage.length > 0 ? '刷新失败' : this.refreshStatus,
          tone: this.taskMessage.length > 0 ? '#D9480F' : '#495057'
        })
        this.CardDivider()
        StatusInfoRow({
          label: '服务状态',
          value: ApiClient.getRuntimeStatusLabel(),
          tone: ApiClient.getRuntimeStatusTone()
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
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
      .fontColor('#111827')
      .maxLines(1)
  }

  @Builder
  TaskMessageText() {
    if (this.taskMessage.length > 0) {
      Text(this.taskMessage)
        .fontSize(13)
        .fontColor('#D9480F')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  RecordMessageText() {
    if (this.recordMessage.length > 0) {
      Text(this.recordMessage)
        .fontSize(13)
        .fontColor(this.recordMessageTone)
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
        .fontColor(['#111827'])
    }
    .width(28)
    .height(28)
    .backgroundColor('#00000000')
    .onClick(() => {
      action();
    })
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

  async refreshTasks(): Promise<void> {
    if (this.refreshing || this.submitting) {
      return;
    }

    this.refreshing = true;
    const response = await ReinspectionService.queryPendingTasksRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.taskMessage = error ? error.message : '复检任务刷新失败';
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    this.taskItems = data ? data.items : [];
    this.refreshStatus = '已刷新';
    this.taskMessage = '';
  }

  async submitRecord(): Promise<void> {
    if (this.submitting) {
      return;
    }

    this.submitting = true;
    const response = await ReinspectionService.submitRecordRemoteFirst({
      taskId: this.taskId,
      result: this.result,
      reinspectedAt: this.reinspectedAt,
      description: this.description
    });
    this.submitting = false;

    this.normalizedTaskId = this.taskId.trim().toUpperCase();
    if (this.normalizedTaskId.length === 0) {
      this.normalizedTaskId = '-';
    }

    if (!response.success) {
      const error = response.error;
      this.recordMessage = error ? error.message : '复检记录提交失败';
      this.recordMessageTone = '#D9480F';
      return;
    }

    const recordNo = response.data ? response.data.recordNo : '';
    this.recordMessage = recordNo.length > 0 ? `复检记录已提交：${recordNo}` : '复检记录已提交';
    this.recordMessageTone = '#087F5B';
    this.taskItems = this.taskItems.filter((item: ReinspectionTaskSummary) => {
      return item.taskNo !== this.normalizedTaskId && item.id !== this.normalizedTaskId;
    });
    this.refreshStatus = '已更新';
  }

  showReinspectedAtPicker(): void {
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.reinspectedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.reinspectedAt = this.formatDateTime(value);
        this.recordMessage = '';
        this.recordMessageTone = '#D9480F';
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

      router.replaceUrl({ url: 'pages/Index' });
    } catch (err) {
      this.recordMessage = '页面跳转失败';
      this.recordMessageTone = '#D9480F';
    }
  }
}
