import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { FaultSeverity } from '../../models/FaultModels';
import { PermissionCode } from '../../models/PermissionModels';
import { MyRepairTaskSummary, RepairReportResult } from '../../models/RepairTaskModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceService } from '../../services/DeviceService';
import { FaultReportService } from '../../services/FaultReportService';
import { RepairTaskService } from '../../services/RepairTaskService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const MY_REPAIR_TASK_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '我的维修',
    items: [
      {
        label: '任务',
        description: '集中查看已接取且需要继续处理的维修任务，保持责任人与任务进度一致'
      },
      {
        label: '报告',
        description: '在维修完成、临时恢复或无法解决时填写处理记录，支撑复检、归档和审计'
      }
    ]
  },
  {
    title: '维修结果',
    items: [
      {
        label: RepairTaskService.formatRepairReportResult(RepairReportResult.Repaired),
        description: '故障已消除并完成必要验证，设备可进入正常运行或后续复检流程'
      },
      {
        label: RepairTaskService.formatRepairReportResult(RepairReportResult.TemporaryRestored),
        description: '通过临时措施恢复有限运行能力，仍需标记遗留风险并安排后续处理'
      },
      {
        label: RepairTaskService.formatRepairReportResult(RepairReportResult.Unresolved),
        description: '当前处理未能消除故障，应说明阻塞原因，并升级、转派或补充资源'
      }
    ]
  }
];

@Entry
@Component
struct MyRepairTask {
  @State taskItems: MyRepairTaskSummary[] = [];
  @State taskId: string = '';
  @State reportResult: string = '';
  @State repairedAt: string = '';
  @State processDescription: string = '';
  @State partsUsed: string = '';
  @State taskMessage: string = '';
  @State reportMessage: string = '';
  @State reportMessageTone: string = AppColors.Danger;
  @State refreshStatus: string = '未刷新';
  @State normalizedTaskId: string = '-';
  @State submittedRepairTaskId: string = '';
  @State refreshing: boolean = false;
  @State submitting: boolean = false;
  private myRepairTaskInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '维修任务说明',
      sections: MY_REPAIR_TASK_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OpsRepairReportCreate)) {
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
          this.ReportForm()
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
        Text('我的维修')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showMyRepairTaskInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('处理已接取任务')
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
  TaskListPanel() {
    Column({ space: 10 }) {
      this.TaskMessageText()

      Row() {
        Text('已接取任务')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor([AppColors.Surface])
        }
        .width(44)
        .height(44)
        .backgroundColor(AppColors.Primary)
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
          ForEach(this.taskItems, (item: MyRepairTaskSummary) => {
            this.TaskItem(item)
          }, (item: MyRepairTaskSummary) => item.id)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  EmptyTaskState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
          .fontSize(36)
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无已接取任务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('接取故障后可在此填写维修报告')
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 28,
      bottom: 28
    })
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TaskItem(item: MyRepairTaskSummary) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
            .fontSize(23)
            .fontColor([AppColors.Surface])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.getSeverityTone(item.severity))

        Column({ space: 4 }) {
          Text(item.deviceName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.taskNo)
            .fontSize(12)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(FaultReportService.formatFaultType(item.faultType))
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)

        Text(FaultReportService.formatSeverity(item.severity))
          .fontSize(13)
          .fontColor(this.getSeverityTone(item.severity))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.isTaskSelected(item) ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.text_clipboard'))
            .fontSize(18)
            .fontColor([AppColors.Surface])

          Text(this.isTaskSelected(item) ? '已选择' : '填写维修报告')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.Surface)
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width('100%')
      }
      .height(46)
      .width('100%')
      .backgroundColor(this.isTaskSelected(item) ? AppColors.Success : AppColors.Primary)
      .onClick(() => {
        this.taskId = item.taskNo;
        this.normalizedTaskId = item.taskNo;
        if (this.normalizedTaskId !== this.submittedRepairTaskId) {
          this.submittedRepairTaskId = '';
        }
        this.reportMessage = '';
        this.reportMessageTone = AppColors.Danger;
      })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .border({
      width: this.isTaskSelected(item) ? 2 : 0,
      color: this.isTaskSelected(item) ? AppColors.Primary : AppColors.Transparent
    })
  }

  @Builder
  ReportForm() {
    Column({ space: 16 }) {
      this.FieldTitle('维修报告')
      this.TaskIdField()
      this.ResultSelector()
      this.RepairedAtField()
      this.ProcessDescriptionField()
      this.PartsUsedField()
      this.ReportMessageText()
      this.ActionButton(this.getSubmitButtonLabel(), $r('sys.symbol.text_clipboard'), this.canSubmitRepairReport(),
        () => {
          this.submitRepairReport();
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
  TaskIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('维修任务编号')

      TextInput({
        placeholder: '输入维修任务编号',
        text: this.taskId
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
          this.taskId = value;
          this.normalizedTaskId = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedTaskId.length === 0) {
            this.normalizedTaskId = '-';
          }
          if (this.normalizedTaskId !== this.submittedRepairTaskId) {
            this.submittedRepairTaskId = '';
          }
          this.reportMessage = '';
          this.reportMessageTone = AppColors.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('维修结果')

      Row({ space: 10 }) {
        this.ResultOption(RepairReportResult.Repaired, $r('sys.symbol.checkmark_circle'))
        this.ResultOption(RepairReportResult.TemporaryRestored, $r('sys.symbol.wrench_and_screwdriver'))
        this.ResultOption(RepairReportResult.Unresolved, $r('sys.symbol.exclamationmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultOption(result: RepairReportResult, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.reportResult === `${result}` ? AppColors.Surface : AppColors.TextPrimary])

        Text(RepairTaskService.formatRepairReportResult(result))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.reportResult === `${result}` ? AppColors.Surface : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.reportResult === `${result}` ? this.getRepairResultTone(result) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.reportResult === `${result}` ? this.getRepairResultTone(result) : AppColors.Border
    })
    .onClick(() => {
      this.reportResult = `${result}`;
      this.reportMessage = '';
      this.reportMessageTone = AppColors.Danger;
    })
  }

  @Builder
  RepairedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('维修完成时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.repairedAt.length > 0 ? this.repairedAt : '选择维修完成时间')
          .fontSize(16)
          .fontColor(this.repairedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
        this.showRepairedAtPicker();
        this.reportMessage = '';
        this.reportMessageTone = AppColors.Danger;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProcessDescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('维修过程')

      TextArea({
        placeholder: '填写故障定位、处理过程、验证结果和遗留风险',
        text: this.processDescription
      })
        .height(132)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(1000)
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
          this.processDescription = value;
          this.reportMessage = '';
          this.reportMessageTone = AppColors.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PartsUsedField() {
    Column({ space: 10 }) {
      this.FieldTitle('更换部件')

      TextArea({
        placeholder: '填写更换部件、数量和序列号；未更换可留空',
        text: this.partsUsed
      })
        .height(90)
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
          this.partsUsed = value;
          this.reportMessage = '';
          this.reportMessageTone = AppColors.Danger;
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
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '标准任务号', value: this.normalizedTaskId, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '维修结果',
          value: this.getRepairResultStatusText(),
          tone: this.getSelectedRepairResultTone()
        })
        this.CardDivider()
        StatusInfoRow({
          label: '刷新状态',
          value: this.taskMessage.length > 0 ? '刷新失败' : this.refreshStatus,
          tone: this.taskMessage.length > 0 ? AppColors.Danger : AppColors.TextSecondary
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
  FieldTitle(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  TaskMessageText() {
    if (this.taskMessage.length > 0) {
      Text(this.taskMessage)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ReportMessageText() {
    if (this.reportMessage.length > 0) {
      Text(this.reportMessage)
        .fontSize(13)
        .fontColor(this.reportMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
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
    .backgroundColor(enabled ? AppColors.Primary : AppColors.Disabled)
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
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
    const response = await RepairTaskService.queryMyRepairTasksRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.taskMessage = error ? error.message : '维修任务刷新失败';
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    this.taskItems = data ? data.items : [];
    this.refreshStatus = '已刷新';
    this.taskMessage = '';
  }

  async submitRepairReport(): Promise<void> {
    if (this.submitting || this.isSelectedRepairTaskSubmitted()) {
      return;
    }

    this.submitting = true;
    const response = await RepairTaskService.submitRepairReportRemoteFirst({
      taskId: this.taskId,
      result: this.reportResult as RepairReportResult,
      repairedAt: this.repairedAt,
      processDescription: this.processDescription,
      partsUsed: this.partsUsed
    });
    this.submitting = false;

    this.normalizedTaskId = DeviceService.normalizeDeviceCode(this.taskId);
    if (this.normalizedTaskId.length === 0) {
      this.normalizedTaskId = '-';
    }

    if (!response.success) {
      const error = response.error;
      this.reportMessage = error ? error.message : '维修报告提交失败';
      this.reportMessageTone = AppColors.Danger;
      return;
    }

    const reportNo = response.data ? response.data.reportNo : '';
    this.reportMessage = reportNo.length > 0 ? `维修报告已提交：${reportNo}` : '维修报告已提交';
    this.reportMessageTone = AppColors.Success;
    this.submittedRepairTaskId = this.normalizedTaskId;
    this.taskItems = this.taskItems.filter((item: MyRepairTaskSummary) => {
      return item.taskNo !== this.normalizedTaskId && item.id !== this.normalizedTaskId;
    });
    this.refreshStatus = '已更新';
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.isSelectedRepairTaskSubmitted()) {
      return '已提交';
    }

    return '提交报告';
  }

  canSubmitRepairReport(): boolean {
    return !this.submitting && !this.isSelectedRepairTaskSubmitted();
  }

  isSelectedRepairTaskSubmitted(): boolean {
    return this.submittedRepairTaskId.length > 0 && this.normalizedTaskId === this.submittedRepairTaskId;
  }

  isTaskSelected(item: MyRepairTaskSummary): boolean {
    const selectedTaskId = this.normalizedTaskId.trim();
    if (selectedTaskId.length === 0 || selectedTaskId === '-') {
      return false;
    }

    return item.taskNo === selectedTaskId || item.id === selectedTaskId;
  }

  getRepairResultStatusText(): string {
    return this.reportResult.length === 0 ? '-' :
      RepairTaskService.formatRepairReportResult(this.reportResult as RepairReportResult);
  }

  getSelectedRepairResultTone(): string {
    return this.reportResult.length === 0 ? AppColors.TextSecondary : this.getRepairResultTone(this.reportResult as RepairReportResult);
  }

  getRepairResultTone(result: RepairReportResult): string {
    switch (result) {
      case RepairReportResult.Repaired:
        return AppColors.Success;
      case RepairReportResult.TemporaryRestored:
        return AppColors.Warning;
      case RepairReportResult.Unresolved:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
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

  showMyRepairTaskInfoDialog(): void {
    this.myRepairTaskInfoDialogController.open();
  }

  showRepairedAtPicker(): void {
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.repairedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.repairedAt = this.formatDateTime(value);
        this.reportMessage = '';
        this.reportMessageTone = AppColors.Danger;
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
