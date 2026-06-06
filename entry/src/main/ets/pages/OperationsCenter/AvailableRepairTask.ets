import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { FaultSeverity } from '../../models/FaultModels';
import { PermissionCode } from '../../models/PermissionModels';
import {
  AvailableRepairTaskQuery,
  AvailableRepairTaskSummary,
  RepairerWorkloadSnapshot,
  RepairerWorkloadStatus
} from '../../models/RepairTaskModels';
import { ApiResponse } from '../../models/ApiModels';
import { ApiClient } from '../../services/ApiClient';
import { FaultReportService } from '../../services/FaultReportService';
import { LocationService, LocationResolutionResult } from '../../services/LocationService';
import { RepairTaskService } from '../../services/RepairTaskService';
import { AuthGuard } from '../../utils/AuthGuard';

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
const REFRESH_TIMEOUT_MS = 5000;

@Entry
@Component
struct AvailableRepairTask {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State radiusKm: number = RepairTaskService.getDefaultRadiusKm();
  @State workloadSnapshot: RepairerWorkloadSnapshot = RepairTaskService.getCurrentWorkloadSnapshot();
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State taskListMessage: string = '';
  @State taskListMessageTone: string = AppColors.Success;
  @State acceptActionMessage: string = '';
  @State acceptActionMessageTone: string = AppColors.Danger;
  @State acceptActionTaskId: string = '';
  @State refreshStatus: string = '未刷新';
  @State locationStatus: string = '未定位';
  @State locationStatusTone: string = AppColors.TextSecondary;
  @State hasCurrentLocation: boolean = false;
  @State currentLongitude: number = 0;
  @State currentLatitude: number = 0;
  @State taskItems: AvailableRepairTaskSummary[] = [];
  @State refreshing: boolean = false;
  @State acceptingTaskId: string = '';

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
      Text('附近故障')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

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
      this.TaskListMessageText()

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

      Text('在线模式连接后可刷新附近故障')
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
            .fontColor([AppColors.OnPrimary])
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

        Text(this.formatDistance(item))
          .fontSize(13)
          .fontColor(item.distanceKm === undefined ? AppColors.TextSecondary : AppColors.Primary)
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

      if (this.acceptActionTaskId === item.id) {
        this.AcceptActionMessageText()
      }
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
        StatusInfoRow({
          label: '定位状态',
          value: this.locationStatus,
          tone: this.locationStatusTone
        })
        this.CardDivider()
        this.RefreshStatusRow()
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
  TaskListMessageText() {
    if (this.taskListMessage.length > 0) {
      Text(this.taskListMessage)
        .fontSize(13)
        .fontColor(this.taskListMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  AcceptActionMessageText() {
    if (this.acceptActionMessage.length > 0) {
      Text(this.acceptActionMessage)
        .fontSize(13)
        .fontColor(this.acceptActionMessageTone)
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
    this.refreshStatus = '刷新中';
    this.message = '';
    this.messageTone = AppColors.Danger;
    this.taskListMessage = '';
    this.acceptActionMessage = '';
    this.acceptActionTaskId = '';
    this.locationStatus = ApiClient.isConfigured() ? '未定位' : '本地模式';
    this.locationStatusTone = ApiClient.isConfigured() ? AppColors.TextSecondary : AppColors.TextSecondary;
    this.hasCurrentLocation = false;
    try {
      const workloadResponse = await this.withRefreshTimeout<RepairerWorkloadSnapshot>(
        RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst(),
        '维修负载状态刷新超时，请稍后手动刷新'
      );
      if (!workloadResponse.success || workloadResponse.data === undefined) {
        const error = workloadResponse.error;
        this.message = error ? error.message : '维修负载状态刷新失败';
        this.messageTone = AppColors.Danger;
        this.refreshStatus = this.isRefreshTimeout(workloadResponse) ? '刷新超时' : '刷新失败';
        return;
      }

      this.applyWorkloadSnapshot(workloadResponse.data);
      if (!this.workloadSnapshot.canAccept) {
        this.taskItems = [];
        this.message = this.workloadSnapshot.message;
        this.messageTone = AppColors.Danger;
        this.refreshStatus = '不可接取';
        return;
      }

      const query: AvailableRepairTaskQuery = {
        radiusKm: this.radiusKm
      };
      let locationMessage = '';
      if (ApiClient.isConfigured()) {
        const locationResult = await this.resolveCurrentLocation();
        if (locationResult.success && locationResult.coordinates !== undefined) {
          query.longitude = locationResult.coordinates.longitude;
          query.latitude = locationResult.coordinates.latitude;
        } else {
          locationMessage = `${locationResult.message}，任务需定位后才可接取。`;
        }
      }

      const response = await this.withRefreshTimeout(
        RepairTaskService.queryAvailableRepairTasksRemoteFirst(query, this.workloadSnapshot),
        '附近故障刷新超时，请稍后手动刷新'
      );

      if (!response.success) {
        const error = response.error;
        this.message = error ? error.message : '附近故障刷新失败';
        this.messageTone = AppColors.Danger;
        this.refreshStatus = this.isRefreshTimeout(response) ? '刷新超时' : '刷新失败';
        return;
      }

      const data = response.data;
      if (data?.workload !== undefined) {
        this.applyWorkloadSnapshot(data.workload);
      }
      this.taskItems = data ? data.items : [];
      this.refreshStatus = '已刷新';
      if (locationMessage.length > 0) {
        this.message = locationMessage;
        this.messageTone = AppColors.Warning;
      } else if (this.workloadSnapshot.status === RepairerWorkloadStatus.LowLoad) {
        this.message = this.workloadSnapshot.message;
        this.messageTone = AppColors.Primary;
      } else {
        this.message = '';
        this.messageTone = AppColors.Danger;
      }
    } catch (err) {
      this.message = '附近故障刷新失败，请稍后手动刷新';
      this.messageTone = AppColors.Danger;
      this.refreshStatus = '刷新失败';
    } finally {
      this.refreshing = false;
    }
  }

  async acceptTask(taskId: string): Promise<void> {
    if (this.acceptingTaskId.length > 0 || this.refreshing) {
      return;
    }

    this.acceptingTaskId = taskId;
    this.acceptActionTaskId = taskId;
    this.acceptActionMessage = '';
    this.acceptActionMessageTone = AppColors.Danger;
    this.taskListMessage = '';
    try {
      const workloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
      if (!workloadResponse.success || workloadResponse.data === undefined) {
        const error = workloadResponse.error;
        this.acceptActionMessage = error ? error.message : '维修负载状态刷新失败';
        this.acceptActionMessageTone = AppColors.Danger;
        return;
      }

      this.applyWorkloadSnapshot(workloadResponse.data);
      const selectedTask = this.findTaskItem(taskId);
      if (selectedTask !== undefined && selectedTask.distanceKm === undefined) {
        this.acceptActionMessage = '任务距离未定位，暂不可接取。请授权位置并刷新后再操作。';
        this.acceptActionMessageTone = AppColors.Danger;
        return;
      }

      if (!this.workloadSnapshot.canAccept ||
        (selectedTask !== undefined &&
          selectedTask.distanceKm !== undefined &&
          selectedTask.distanceKm > this.workloadSnapshot.maxRadiusKm)) {
        this.acceptActionMessage = this.workloadSnapshot.canAccept ?
          `当前处于${RepairTaskService.formatWorkloadStatus(this.workloadSnapshot.status)}状态，仅可接取${this.workloadSnapshot.maxRadiusKm}公里内的维修任务。` :
          this.workloadSnapshot.message;
        this.acceptActionMessageTone = AppColors.Danger;
        return;
      }

      if (ApiClient.isConfigured() && !this.hasCurrentLocation) {
        this.acceptActionMessage = '当前位置未确认，暂不可接取。请先刷新附近故障。';
        this.acceptActionMessageTone = AppColors.Danger;
        return;
      }

      const response = await RepairTaskService.acceptRepairTaskRemoteFirst(
        taskId,
        this.hasCurrentLocation ? this.currentLongitude : undefined,
        this.hasCurrentLocation ? this.currentLatitude : undefined
      );

      if (!response.success) {
        const error = response.error;
        this.acceptActionMessage = error ? error.message : '维修任务接取失败';
        this.acceptActionMessageTone = AppColors.Danger;
        return;
      }

      this.taskItems = this.taskItems.filter((item: AvailableRepairTaskSummary) => {
        return item.id !== taskId;
      });
      this.refreshStatus = '已接取';
      this.acceptActionMessage = '';
      this.acceptActionTaskId = '';
      this.taskListMessage = '维修任务已接取，可在我的维修中处理';
      this.taskListMessageTone = AppColors.Success;
      const nextWorkloadResponse = await RepairTaskService.getCurrentWorkloadSnapshotRemoteFirst();
      if (nextWorkloadResponse.success && nextWorkloadResponse.data !== undefined) {
        this.applyWorkloadSnapshot(nextWorkloadResponse.data);
      }
    } catch (err) {
      this.acceptActionMessage = '维修任务接取失败，请稍后重试';
      this.acceptActionMessageTone = AppColors.Danger;
    } finally {
      this.acceptingTaskId = '';
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
    this.taskListMessage = '';
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
      item.distanceKm !== undefined &&
      item.distanceKm <= this.workloadSnapshot.maxRadiusKm;
  }

  formatDistance(item: AvailableRepairTaskSummary): string {
    return item.distanceKm === undefined ? '待定位' : `${item.distanceKm.toFixed(1)} km`;
  }

  withRefreshTimeout<T>(request: Promise<ApiResponse<T>>, timeoutMessage: string): Promise<ApiResponse<T>> {
    return new Promise<ApiResponse<T>>((resolve: (value: ApiResponse<T>) => void) => {
      const timerId = setTimeout(() => {
        resolve({
          success: false,
          error: {
            code: 'REFRESH_TIMEOUT',
            message: timeoutMessage
          },
          timestamp: new Date().toISOString()
        });
      }, REFRESH_TIMEOUT_MS);

      request.then((response: ApiResponse<T>) => {
        clearTimeout(timerId);
        resolve(response);
      }).catch(() => {
        clearTimeout(timerId);
        resolve({
          success: false,
          error: {
            code: 'REFRESH_FAILED',
            message: '附近故障刷新失败，请稍后手动刷新'
          },
          timestamp: new Date().toISOString()
        });
      });
    });
  }

  isRefreshTimeout<T>(response: ApiResponse<T>): boolean {
    return response.error !== undefined && `${response.error.code}` === 'REFRESH_TIMEOUT';
  }

  async resolveCurrentLocation(): Promise<LocationResolutionResult> {
    this.locationStatus = '定位中';
    this.locationStatusTone = AppColors.TextSecondary;
    const result = await LocationService.resolveCurrentLocation(this.getUIContext().getHostContext());
    if (result.success && result.coordinates !== undefined) {
      this.hasCurrentLocation = true;
      this.currentLongitude = result.coordinates.longitude;
      this.currentLatitude = result.coordinates.latitude;
      this.locationStatus = '已定位';
      this.locationStatusTone = AppColors.Success;
      return result;
    }

    this.hasCurrentLocation = false;
    this.locationStatus = '未定位';
    this.locationStatusTone = AppColors.Warning;
    return result;
  }

  findTaskItem(taskId: string): AvailableRepairTaskSummary | undefined {
    return this.taskItems.find((item: AvailableRepairTaskSummary) => {
      return item.id === taskId;
    });
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
