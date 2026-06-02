import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { FaultSeverity } from '../../models/FaultModels';
import { PermissionCode } from '../../models/PermissionModels';
import {
  AvailableRepairTaskSummary,
  RepairerWorkloadSnapshot,
  RepairerWorkloadStatus
} from '../../models/RepairTaskModels';
import { ApiClient } from '../../services/ApiClient';
import { FaultReportService } from '../../services/FaultReportService';
import { RepairTaskService } from '../../services/RepairTaskService';
import { AuthGuard } from '../../utils/AuthGuard';

const AVAILABLE_TASK_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '附近故障',
    items: [
      {
        label: '服务范围',
        description: '按当前位置、服务半径和系统判定的维修负载筛选可接取任务，减少无效响应和跨区处理'
      },
      {
        label: '接取',
        description: '维修人员主动接取后承担处理责任，任务进入我的维修页面继续跟进'
      },
      {
        label: '负载状态',
        description: '系统根据进行中的维修任务数判定空闲、低负载或忙碌状态，并据此限制刷新范围和接取能力'
      }
    ]
  }
];

const RADIUS_PICKER_OPTIONS: string[] = [
  '1 km',
  '2 km',
  '3 km',
  '4 km',
  '5 km',
  '6 km',
  '7 km',
  '8 km',
  '9 km',
  '10 km',
  '11 km',
  '12 km',
  '13 km',
  '14 km',
  '15 km',
  '16 km',
  '17 km',
  '18 km',
  '19 km',
  '20 km'
];

@Entry
@Component
struct AvailableRepairTask {
  @State radiusKm: number = RepairTaskService.getDefaultRadiusKm();
  @State workloadSnapshot: RepairerWorkloadSnapshot = RepairTaskService.getCurrentWorkloadSnapshot();
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
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
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OpsRepairTaskAccept)) {
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
        Text('附近故障')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showAvailableTaskInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('查看可接取维修任务')
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
  FilterPanel() {
    Column({ space: 16 }) {
      this.FieldTitle('查询范围')
      this.RadiusPicker()

      this.FieldTitle('负载状态')
      this.WorkloadSnapshotPanel()

      this.MessageText()
      this.ActionButton(this.refreshing ? '刷新中' : '刷新任务', $r('sys.symbol.arrow_clockwise'), this.isRefreshEnabled(),
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
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RadiusPicker() {
    Column({ space: 8 }) {
      if (this.workloadSnapshot.canAccept) {
        TextPicker({
          range: this.getRadiusPickerOptions(),
          selected: this.getRadiusPickerSelectedIndex()
        })
          .height(126)
          .width('100%')
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .onChange((value: string | string[], index: number | number[]) => {
            this.applyRadiusPickerIndex(index);
          })
      } else {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
            .fontSize(22)
            .fontColor([AppColors.Danger])

          Text('当前状态暂不可接取')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.Danger)
            .maxLines(1)
        }
        .height(88)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
      }

      Text(`当前选择：${this.getCurrentRadiusText()}`)
        .fontSize(13)
        .fontColor(this.workloadSnapshot.canAccept ? AppColors.Primary : AppColors.Danger)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: 8,
      bottom: 10
    })
    .backgroundColor(AppColors.FieldBackground)
    .borderRadius(18)
    .border({
      width: 1,
      color: AppColors.Border
    })
  }

  @Builder
  WorkloadSnapshotPanel() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph(this.getWorkloadSymbol())
          .fontSize(21)
          .fontColor([RepairTaskService.getWorkloadStatusTone(this.workloadSnapshot.status)])

        Text(RepairTaskService.formatWorkloadStatus(this.workloadSnapshot.status))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(RepairTaskService.getWorkloadStatusTone(this.workloadSnapshot.status))
          .maxLines(1)

        Blank()

        Text(`${this.workloadSnapshot.activeTaskCount}/${this.workloadSnapshot.maxActiveTaskCount}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.workloadSnapshot.message)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .lineHeight(19)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 14,
      right: 14,
      top: 12,
      bottom: 12
    })
    .backgroundColor(AppColors.FieldBackground)
    .borderRadius(18)
    .border({
      width: 1,
      color: AppColors.Border
    })
  }

  @Builder
  TaskListPanel() {
    Column({ space: 10 }) {
      Text('可接取任务')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
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
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无可接取任务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('连接后端服务后可刷新附近故障')
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
  TaskItem(item: AvailableRepairTaskSummary) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.exclamationmark_message'))
            .fontSize(24)
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

          Text(item.deviceCode)
            .fontSize(12)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(`${item.distanceKm.toFixed(1)} km`)
          .fontSize(13)
          .fontColor(AppColors.Primary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
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

      Text(item.location)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      this.ActionButton(this.acceptingTaskId === item.id ? '接取中' : '接取任务', $r('sys.symbol.checkmark_circle'),
        this.isTaskAcceptEnabled(item), () => {
          this.acceptTask(item.id);
        })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('查询状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '可接取范围',
          value: this.getAvailableRadiusText(),
          tone: AppColors.TextSecondary
        })
        this.CardDivider()
        StatusInfoRow({ label: '当前范围', value: this.getCurrentRadiusText(), tone: AppColors.Primary })
        this.CardDivider()
        StatusInfoRow({
          label: '负载状态',
          value: RepairTaskService.formatWorkloadStatus(this.workloadSnapshot.status),
          tone: RepairTaskService.getWorkloadStatusTone(this.workloadSnapshot.status)
        })
        this.CardDivider()
        StatusInfoRow({
          label: '进行中任务',
          value: `${this.workloadSnapshot.activeTaskCount}/${this.workloadSnapshot.maxActiveTaskCount}`,
          tone: AppColors.TextSecondary
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
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
        .fontColor(AppColors.TextPrimary)
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
    const workloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
    if (!workloadResponse.success || workloadResponse.data === undefined) {
      this.refreshing = false;
      const error = workloadResponse.error;
      this.message = error ? error.message : '维修负载状态刷新失败';
      this.messageTone = AppColors.Danger;
      this.refreshStatus = '刷新失败';
      return;
    }

    this.applyWorkloadSnapshot(workloadResponse.data);
    if (!this.workloadSnapshot.canAccept) {
      this.refreshing = false;
      this.taskItems = [];
      this.message = this.workloadSnapshot.message;
      this.messageTone = AppColors.Danger;
      this.refreshStatus = '不可接取';
      return;
    }

    const response = await RepairTaskService.queryAvailableRepairTasksRemoteFirst({
      radiusKm: this.radiusKm
    }, this.workloadSnapshot);
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '附近故障刷新失败';
      this.messageTone = AppColors.Danger;
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    if (data?.workload !== undefined) {
      this.applyWorkloadSnapshot(data.workload);
    }
    this.taskItems = data ? data.items : [];
    this.refreshStatus = '已刷新';
    if (this.workloadSnapshot.status === RepairerWorkloadStatus.LowLoad) {
      this.message = this.workloadSnapshot.message;
      this.messageTone = AppColors.Primary;
    } else {
      this.message = '';
      this.messageTone = AppColors.Danger;
    }
  }

  async acceptTask(taskId: string): Promise<void> {
    if (this.acceptingTaskId.length > 0 || this.refreshing) {
      return;
    }

    this.acceptingTaskId = taskId;
    const workloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
    if (!workloadResponse.success || workloadResponse.data === undefined) {
      this.acceptingTaskId = '';
      const error = workloadResponse.error;
      this.message = error ? error.message : '维修负载状态刷新失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.applyWorkloadSnapshot(workloadResponse.data);
    const selectedTask = this.findTaskItem(taskId);
    if (!this.workloadSnapshot.canAccept ||
      (selectedTask !== undefined && selectedTask.distanceKm > this.workloadSnapshot.maxRadiusKm)) {
      this.acceptingTaskId = '';
      this.message = this.workloadSnapshot.canAccept ?
        `当前处于${RepairTaskService.formatWorkloadStatus(this.workloadSnapshot.status)}状态，仅可接取${this.workloadSnapshot.maxRadiusKm}公里内的维修任务。` :
        this.workloadSnapshot.message;
      this.messageTone = AppColors.Danger;
      return;
    }

    const response = await RepairTaskService.acceptRepairTaskRemoteFirst(taskId);
    this.acceptingTaskId = '';

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '维修任务接取失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.taskItems = this.taskItems.filter((item: AvailableRepairTaskSummary) => {
      return item.id !== taskId;
    });
    this.refreshStatus = '已接取';
    this.message = '维修任务已接取，可在我的维修中处理';
    this.messageTone = AppColors.Success;
    const nextWorkloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
    if (nextWorkloadResponse.success && nextWorkloadResponse.data !== undefined) {
      this.applyWorkloadSnapshot(nextWorkloadResponse.data);
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

  getRefreshStatusTone(): string {
    if (this.isFailureMessageVisible()) {
      return AppColors.Danger;
    }

    if (this.refreshStatus === '已刷新' || this.refreshStatus === '已接取') {
      return AppColors.Success;
    }

    return AppColors.TextSecondary;
  }

  isFailureMessageVisible(): boolean {
    return this.message.length > 0 && this.messageTone === AppColors.Danger;
  }

  applyRadiusPickerIndex(index: number | number[]): void {
    let selectedIndex = 0;
    if (typeof index === 'number') {
      selectedIndex = index;
    } else if (index.length > 0) {
      selectedIndex = index[0];
    }

    this.radiusKm = Math.min(selectedIndex + 1, this.workloadSnapshot.maxRadiusKm);
    this.message = '';
    this.messageTone = AppColors.Danger;
  }

  applyWorkloadSnapshot(workloadSnapshot: RepairerWorkloadSnapshot): void {
    this.workloadSnapshot = workloadSnapshot;
    if (!workloadSnapshot.canAccept) {
      return;
    }

    if (this.radiusKm > workloadSnapshot.maxRadiusKm) {
      this.radiusKm = workloadSnapshot.maxRadiusKm;
    }

    if (this.radiusKm < 1) {
      this.radiusKm = 1;
    }
  }

  getRadiusPickerOptions(): string[] {
    return RADIUS_PICKER_OPTIONS.slice(0, this.workloadSnapshot.maxRadiusKm);
  }

  getRadiusPickerSelectedIndex(): number {
    if (!this.workloadSnapshot.canAccept) {
      return 0;
    }

    return Math.max(0, Math.min(this.radiusKm, this.workloadSnapshot.maxRadiusKm) - 1);
  }

  getCurrentRadiusText(): string {
    if (!this.workloadSnapshot.canAccept) {
      return '不可接取';
    }

    return `${this.radiusKm} km`;
  }

  getAvailableRadiusText(): string {
    if (!this.workloadSnapshot.canAccept) {
      return '暂不可接取';
    }

    return `1-${this.workloadSnapshot.maxRadiusKm} km`;
  }

  getWorkloadSymbol(): Resource {
    if (this.workloadSnapshot.status === RepairerWorkloadStatus.Busy) {
      return $r('sys.symbol.exclamationmark_circle');
    }

    if (this.workloadSnapshot.status === RepairerWorkloadStatus.LowLoad) {
      return $r('sys.symbol.wrench_and_screwdriver');
    }

    return $r('sys.symbol.checkmark_circle');
  }

  isRefreshEnabled(): boolean {
    return !this.refreshing && this.acceptingTaskId.length === 0;
  }

  isTaskAcceptEnabled(item: AvailableRepairTaskSummary): boolean {
    return this.acceptingTaskId.length === 0 &&
      !this.refreshing &&
      this.workloadSnapshot.canAccept &&
      item.distanceKm <= this.workloadSnapshot.maxRadiusKm;
  }

  findTaskItem(taskId: string): AvailableRepairTaskSummary | undefined {
    return this.taskItems.find((item: AvailableRepairTaskSummary) => {
      return item.id === taskId;
    });
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

      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
