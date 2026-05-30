import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import { StatusInfoRow } from '../components/StatusInfoRow';
import { FaultSeverity } from '../models/FaultModels';
import { AvailableRepairTaskSummary, RepairerAvailability } from '../models/RepairTaskModels';
import { ApiClient } from '../services/ApiClient';
import { FaultReportService } from '../services/FaultReportService';
import { RepairTaskService } from '../services/RepairTaskService';
import { AuthGuard } from '../utils/AuthGuard';

const AVAILABLE_TASK_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '附近故障',
    items: [
      {
        label: '服务范围',
        description: '按当前位置、服务半径和任务状态筛选可接取任务，减少无效响应和跨区处理'
      },
      {
        label: '接取',
        description: '维修人员主动接取后承担处理责任，任务进入我的维修页面继续跟进'
      },
      {
        label: '空闲状态',
        description: '仅空闲人员可刷新任务列表，避免忙碌状态下误接任务影响故障响应效率'
      }
    ]
  }
];

@Entry
@Component
struct AvailableRepairTask {
  @State radiusKm: number = RepairTaskService.getDefaultRadiusKm();
  @State availability: RepairerAvailability = RepairerAvailability.Idle;
  @State message: string = '';
  @State messageTone: string = '#D9480F';
  @State refreshStatus: string = '未刷新';
  @State taskItems: AvailableRepairTaskSummary[] = [];
  @State refreshing: boolean = false;
  @State acceptingTaskId: string = '';
  private availableTaskInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '附近故障说明',
      sections: AVAILABLE_TASK_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    AuthGuard.requireAuthenticated(this.getUIContext());
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.FilterPanel()
          this.TaskListPanel()
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
        Text('附近故障')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showAvailableTaskInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('查看可接取维修任务')
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
  FilterPanel() {
    Column({ space: 16 }) {
      this.FieldTitle('查询范围')
      Row({ space: 10 }) {
        this.RadiusOption(5)
        this.RadiusOption(10)
        this.RadiusOption(20)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.FieldTitle('维修状态')
      Row({ space: 10 }) {
        this.AvailabilityOption(RepairerAvailability.Idle, $r('sys.symbol.checkmark_circle'))
        this.AvailabilityOption(RepairerAvailability.Busy, $r('sys.symbol.wrench_and_screwdriver'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.MessageText()
      this.ActionButton(this.refreshing ? '刷新中' : '刷新任务', $r('sys.symbol.arrow_clockwise'), !this.refreshing,
        () => {
          this.refreshTasks();
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
  RadiusOption(radiusKm: number) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(`${radiusKm} km`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.radiusKm === radiusKm ? '#FFFFFF' : '#111827')
        .maxLines(1)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.radiusKm === radiusKm ? '#2F6FED' : '#F7F9FC')
    .border({
      width: 1,
      color: this.radiusKm === radiusKm ? '#2F6FED' : '#D6DAE1'
    })
    .onClick(() => {
      this.radiusKm = radiusKm;
      this.message = '';
      this.messageTone = '#D9480F';
    })
  }

  @Builder
  AvailabilityOption(availability: RepairerAvailability, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.availability === availability ? '#FFFFFF' : '#111827'])

        Text(RepairTaskService.formatAvailability(availability))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.availability === availability ? '#FFFFFF' : '#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.availability === availability ? '#2F6FED' : '#F7F9FC')
    .border({
      width: 1,
      color: this.availability === availability ? '#2F6FED' : '#D6DAE1'
    })
    .onClick(() => {
      this.availability = availability;
      this.message = '';
      this.messageTone = '#D9480F';
    })
  }

  @Builder
  TaskListPanel() {
    Column({ space: 10 }) {
      Text('可接取任务')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      if (this.taskItems.length === 0) {
        this.EmptyTaskState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.taskItems, (item: AvailableRepairTaskSummary) => {
            this.TaskItem(item)
          }, (item: AvailableRepairTaskSummary) => item.id)
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
        SymbolGlyph($r('sys.symbol.location_up'))
          .fontSize(38)
          .fontColor(['#2F6FED'])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor('#EEF4FF')

      Text('暂无可接取任务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Text('连接后端服务后可刷新附近故障')
        .fontSize(13)
        .fontColor('#6B7280')
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
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TaskItem(item: AvailableRepairTaskSummary) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.exclamationmark_message'))
            .fontSize(24)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.getSeverityTone(item.severity))

        Column({ space: 4 }) {
          Text(item.deviceName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.deviceCode)
            .fontSize(12)
            .fontColor('#6B7280')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(`${item.distanceKm.toFixed(1)} km`)
          .fontSize(13)
          .fontColor('#2F6FED')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(FaultReportService.formatFaultType(item.faultType))
          .fontSize(13)
          .fontColor('#374151')
          .layoutWeight(1)
          .maxLines(1)

        Text(FaultReportService.formatSeverity(item.severity))
          .fontSize(13)
          .fontColor(this.getSeverityTone(item.severity))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')

      Text(item.location)
        .fontSize(13)
        .fontColor('#6B7280')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      this.ActionButton(this.acceptingTaskId === item.id ? '接取中' : '接取任务', $r('sys.symbol.checkmark_circle'),
        this.acceptingTaskId.length === 0 && !this.refreshing, () => {
          this.acceptTask(item.id);
        })
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('查询状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '推荐范围',
          value: `${RepairTaskService.getDefaultRadiusKm()} km`,
          tone: '#374151'
        })
        this.CardDivider()
        StatusInfoRow({ label: '当前范围', value: `${this.radiusKm} km`, tone: '#2F6FED' })
        this.CardDivider()
        StatusInfoRow({
          label: '维修状态',
          value: RepairTaskService.formatAvailability(this.availability),
          tone: this.availability === RepairerAvailability.Idle ? '#087F5B' : '#D9480F'
        })
        this.CardDivider()
        this.RefreshStatusRow()
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

  @Builder
  RefreshStatusRow() {
    Row() {
      Text('刷新状态')
        .fontSize(15)
        .fontColor('#111827')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.isFailureMessageVisible() ? '刷新失败' : this.refreshStatus)
        .fontSize(15)
        .fontColor(this.getRefreshStatusTone())
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

  async refreshTasks(): Promise<void> {
    if (this.refreshing || this.acceptingTaskId.length > 0) {
      return;
    }

    this.refreshing = true;
    const response = await RepairTaskService.queryAvailableRepairTasksRemoteFirst({
      radiusKm: this.radiusKm,
      availability: this.availability
    });
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '附近故障刷新失败';
      this.messageTone = '#D9480F';
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    this.taskItems = data ? data.items : [];
    this.refreshStatus = '已刷新';
    this.message = '';
    this.messageTone = '#D9480F';
  }

  async acceptTask(taskId: string): Promise<void> {
    if (this.acceptingTaskId.length > 0 || this.refreshing) {
      return;
    }

    this.acceptingTaskId = taskId;
    const response = await RepairTaskService.acceptRepairTaskRemoteFirst(taskId);
    this.acceptingTaskId = '';

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '维修任务接取失败';
      this.messageTone = '#D9480F';
      return;
    }

    this.taskItems = this.taskItems.filter((item: AvailableRepairTaskSummary) => {
      return item.id !== taskId;
    });
    this.refreshStatus = '已接取';
    this.message = '维修任务已接取，可在我的维修中处理';
    this.messageTone = '#087F5B';
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

  getRefreshStatusTone(): string {
    if (this.isFailureMessageVisible()) {
      return '#D9480F';
    }

    if (this.refreshStatus === '已刷新' || this.refreshStatus === '已接取') {
      return '#087F5B';
    }

    return '#495057';
  }

  isFailureMessageVisible(): boolean {
    return this.message.length > 0 && this.messageTone === '#D9480F';
  }

  showAvailableTaskInfoDialog(): void {
    this.availableTaskInfoDialogController.open();
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
