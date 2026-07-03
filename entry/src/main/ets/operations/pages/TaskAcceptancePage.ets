import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { StatusInfoRow } from '../../shared/components/StatusInfoRow';
import { FaultSeverity, FaultType } from '../models/FaultModels';
import { PermissionCode } from '../../user/models/PermissionModels';
import {
  TaskAcceptanceQuery,
  TaskAcceptanceItem,
  RepairerWorkloadSnapshot,
  RepairerWorkloadStatus
} from '../models/RepairTaskModels';
import { ApiResponse } from '../../shared/models/ApiModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { FaultReportService } from '../services/FaultReportService';
import { LocationService, LocationResolutionResult } from '../services/LocationService';
import { RepairTaskService } from '../services/RepairTaskService';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';

const REFRESH_TIMEOUT_MS = 5000;
const TASK_ACCEPTANCE_TYPE_FILTER_OPTIONS: string[] =
  ['全部', '运行异常', '部件损坏', '通信故障', '逻辑故障', '能源故障', '外部因素', '其他'];
const TASK_ACCEPTANCE_TYPE_FILTER_VALUES: string[] =
  ['', `${FaultType.OperationAbnormal}`, `${FaultType.HardwareDamage}`,
    `${FaultType.CommunicationFault}`, `${FaultType.LogicFault}`, `${FaultType.EnergyFault}`,
    `${FaultType.ExternalFactor}`,
    `${FaultType.Other}`];
const TASK_ACCEPTANCE_SEVERITY_FILTER_OPTIONS: string[] = ['全部', '紧急', '严重', '一般', '轻微'];
const TASK_ACCEPTANCE_SEVERITY_FILTER_VALUES: string[] = ['', `${FaultSeverity.Emergency}`, `${FaultSeverity.Severe}`,
  `${FaultSeverity.General}`, `${FaultSeverity.Minor}`];
const TASK_TYPE_CHIP_OPTIONS: string[] = ['全部', '维修任务', '复检任务'];
const TASK_TYPE_CHIP_VALUES: string[] = ['', 'REPAIR', 'REINSPECTION'];
const TASK_FILTER_CONTROL_HEIGHT = 158;

@Entry
@Component
struct TaskAcceptancePage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State radiusKm: number = RepairTaskService.getDefaultRadiusKm();
  @State workloadSnapshot: RepairerWorkloadSnapshot = RepairTaskService.getCurrentWorkloadSnapshot();
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State taskListMessage: string = '';
  @State taskListMessageTone: string = UiFeedbackTone.Success;
  @State acceptActionMessage: string = '';
  @State acceptActionMessageTone: string = UiFeedbackTone.Danger;
  @State acceptActionTaskId: string = '';
  @State hasCurrentLocation: boolean = false;
  @State currentLongitude: number = 0;
  @State currentLatitude: number = 0;
  @State allTaskItems: TaskAcceptanceItem[] = [];
  @State taskItems: TaskAcceptanceItem[] = [];
  @State refreshing: boolean = false;
  @State acceptingTaskId: string = '';
  @State faultTypeFilterIndex: number = 0;
  @State severityFilterIndex: number = 0;
  @State taskTypeFilterIndex: number = 0;
  @State filterResetRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), [
      PermissionCode.OperationsCenterRepairTaskAccept,
      PermissionCode.OperationsCenterReinspectionTaskAccept
    ])) {
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
      Text('任务接取')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Task Acceptance')
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
  FilterPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '工作状态',
        subtitle: ''
      })

      this.WorkStatusForm()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  WorkStatusForm() {
    Column() {
      StatusInfoRow({
        label: '当前状态',
        value: RepairTaskService.formatWorkloadStatus(this.workloadSnapshot.status),
        tone: RepairTaskService.getWorkloadStatusTone(this.workloadSnapshot.status),
        valueMaxLines: 1
      })
      this.CardDivider()
      StatusInfoRow({
        label: '已接取任务',
        value: `${this.workloadSnapshot.activeTaskCount}/${this.workloadSnapshot.maxActiveTaskCount}`,
        tone: AppColors.Primary,
        valueMaxLines: 1
      })
      this.CardDivider()
      StatusInfoRow({
        label: '可接取半径',
        value: this.getAvailableRadiusText(),
        tone: this.workloadSnapshot.canAccept ? AppColors.Primary : AppColors.Danger,
        valueMaxLines: 1
      })
    }
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
  }

  @Builder
  RadiusPicker() {
    Column({ space: 10 }) {
      Row() {
        Text('接取半径')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)

        Text(this.getCurrentRadiusText())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.workloadSnapshot.canAccept ? AppColors.Primary : AppColors.Danger)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Slider({
        value: this.radiusKm,
        min: 0,
        max: Math.max(1, this.workloadSnapshot.maxRadiusKm),
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .enabled(this.workloadSnapshot.canAccept && !this.refreshing && this.acceptingTaskId.length === 0)
        .onChange((value: number) => {
          this.applyRadiusSliderValue(value);
        })
    }
    .width('100%')
  }

  @Builder
  TaskListPanel() {
    Column({ space: 10 }) {
      this.TaskListMessageText()

      AppSectionTitle({
        title: '可接取任务',
        subtitle: ''
      })

      this.TaskFilterPanel()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  TaskFilterPanel() {
    Column({ space: 14 }) {
      this.RadiusPicker()

      this.TaskFilterControl()

      this.TaskResultContent()
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 16,
      bottom: 14
    })
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TaskFilterControl() {
    if (this.filterResetRevision % 2 === 0) {
      this.TaskFilterInstance()
    } else {
      this.TaskFilterInstance()
    }
  }

  @Builder
  TaskFilterInstance() {
    Column() {
      Filter({
        multiFilters: this.getTaskFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyTaskFilterResults(filterResults);
        },
        filterType: FilterType.LIST_FILTER
      }) {
        Column()
          .width('100%')
          .height(1)
      }
    }
    .height(TASK_FILTER_CONTROL_HEIGHT)
    .width('100%')
    .clip(true)
  }

  @Builder
  TaskResultContent() {
    Column({ space: 12 }) {
      this.MessageText()
      this.ListActionButtons()
      this.TaskFilterResultList()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ListActionButtons() {
    Row({ space: 10 }) {
      this.ResetButton()
      Column() {
        this.ActionButton(this.refreshing ? '刷新中' : '刷新', $r('sys.symbol.arrow_clockwise'),
          this.isRefreshEnabled(), () => {
            this.refreshTasks();
          })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ResetButton() {
    Button({ type: ButtonType.Capsule, stateEffect: this.isRefreshEnabled() }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.xmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text('重置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .layoutWeight(1)
    .backgroundColor(AppColors.FieldBackground)
    .border({ width: 1, color: AppColors.Border })
    .enabled(this.isRefreshEnabled())
    .onClick(() => {
      this.resetFilters();
    })
  }

  @Builder
  TaskFilterResultList() {
    Column({ space: 12 }) {
      if (this.taskItems.length === 0) {
        this.EmptyTaskState()
      } else {
        ForEach(this.taskItems, (item: TaskAcceptanceItem) => {
          this.TaskItem(item)
        }, (item: TaskAcceptanceItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  EmptyTaskState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.location_up'))
          .fontSize(38)
          .fontColor([AppColors.Success])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.SuccessSurface)

      Text('暂无可接取任务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 28,
      bottom: 28
    })
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TaskItem(item: TaskAcceptanceItem) {
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
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
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
      InlineMessageSurface({
        message: this.message,
        tone: this.messageTone
      })
    }
  }

  @Builder
  TaskListMessageText() {
    if (this.taskListMessage.length > 0) {
      InlineMessageSurface({
        message: this.taskListMessage,
        tone: this.taskListMessageTone
      })
    }
  }

  @Builder
  AcceptActionMessageText() {
    if (this.acceptActionMessage.length > 0) {
      InlineMessageSurface({
        message: this.acceptActionMessage,
        tone: this.acceptActionMessageTone
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

  async refreshTasks(): Promise<void> {
    if (this.refreshing || this.acceptingTaskId.length > 0) {
      return;
    }

    if (!ApiClient.isConfigured()) {
      this.clearTaskListForUnavailableOnlineMode();
      return;
    }

    this.refreshing = true;
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.taskListMessage = '';
    this.acceptActionMessage = '';
    this.acceptActionTaskId = '';
    this.hasCurrentLocation = false;
    try {
      const query: TaskAcceptanceQuery = {
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
        RepairTaskService.queryTaskAcceptanceRemoteFirst(query, this.workloadSnapshot),
        UiFeedbackService.operationUnavailable('刷新')
      );

      if (!response.success) {
        const error = response.error;
        this.message = UiFeedbackService.operationError(error, '刷新');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      const data = response.data;
      if (data?.workload !== undefined) {
        this.applyWorkloadSnapshot(data.workload);
      }
      this.allTaskItems = data ? data.items : [];
      this.applyTaskFilters();
      if (locationMessage.length > 0) {
        this.message = locationMessage;
        this.messageTone = UiFeedbackTone.Warning;
      } else if (this.workloadSnapshot.status === RepairerWorkloadStatus.LowLoad) {
        this.message = this.workloadSnapshot.message;
        this.messageTone = UiFeedbackTone.Info;
      } else {
        this.message = UiFeedbackService.operationSuccess('刷新');
        this.messageTone = UiFeedbackTone.Success;
      }
    } catch (err) {
      this.message = UiFeedbackService.operationUnavailable('刷新');
      this.messageTone = UiFeedbackTone.Danger;
    } finally {
      this.refreshing = false;
    }
  }

  clearTaskListForUnavailableOnlineMode(): void {
    this.allTaskItems = [];
    this.taskItems = [];
    this.message = UiFeedbackService.operationUnavailable('任务接取');
    this.messageTone = UiFeedbackTone.Danger;
    this.taskListMessage = '';
    this.acceptActionMessage = '';
    this.acceptActionTaskId = '';
    this.hasCurrentLocation = false;
  }

  async acceptTask(taskId: string): Promise<void> {
    if (this.acceptingTaskId.length > 0 || this.refreshing) {
      return;
    }

    this.acceptingTaskId = taskId;
    this.acceptActionTaskId = taskId;
    this.acceptActionMessage = '';
    this.acceptActionMessageTone = UiFeedbackTone.Danger;
    this.taskListMessage = '';
    try {
      const selectedTask = this.findTaskItem(taskId);
      if (selectedTask !== undefined && selectedTask.distanceKm === undefined) {
        this.acceptActionMessage = UiFeedbackService.operationUnavailable('任务接取');
        this.acceptActionMessageTone = UiFeedbackTone.Danger;
        return;
      }

      if (!this.workloadSnapshot.canAccept ||
        (selectedTask !== undefined &&
          selectedTask.distanceKm !== undefined &&
          selectedTask.distanceKm > this.workloadSnapshot.maxRadiusKm)) {
        this.acceptActionMessage = this.workloadSnapshot.canAccept ?
          UiFeedbackService.sanitize(`当前处于${RepairTaskService.formatWorkloadStatus(
            this.workloadSnapshot.status)}状态，仅可接取${this.workloadSnapshot.maxRadiusKm}公里内的维修任务。`) :
          UiFeedbackService.sanitize(this.workloadSnapshot.message);
        this.acceptActionMessageTone = UiFeedbackTone.Danger;
        return;
      }

      if (ApiClient.isConfigured() && !this.hasCurrentLocation) {
        this.acceptActionMessage = UiFeedbackService.operationUnavailable('任务接取');
        this.acceptActionMessageTone = UiFeedbackTone.Danger;
        return;
      }

      const response = await RepairTaskService.acceptTaskRemoteFirst(
        taskId,
        selectedTask === undefined ? 'REPAIR' : selectedTask.taskType,
        this.hasCurrentLocation ? this.currentLongitude : undefined,
        this.hasCurrentLocation ? this.currentLatitude : undefined
      );

      if (!response.success) {
        const error = response.error;
        this.acceptActionMessage = UiFeedbackService.operationError(error, '任务接取');
        this.acceptActionMessageTone = UiFeedbackTone.Danger;
        return;
      }

      this.allTaskItems = this.allTaskItems.filter((item: TaskAcceptanceItem) => {
        return item.id !== taskId;
      });
      this.applyTaskFilters();
      this.acceptActionMessage = '';
      this.acceptActionTaskId = '';
      this.taskListMessage = UiFeedbackService.operationSuccess('任务接取');
      this.taskListMessageTone = UiFeedbackTone.Success;
      this.applyWorkloadSnapshot(RepairTaskService.createWorkloadSnapshot(this.workloadSnapshot.activeTaskCount + 1));
    } catch (err) {
      this.acceptActionMessage = UiFeedbackService.operationUnavailable('任务接取');
      this.acceptActionMessageTone = UiFeedbackTone.Danger;
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

  applyRadiusSliderValue(value: number): void {
    const normalizedValue = Math.max(0, Math.min(this.workloadSnapshot.maxRadiusKm, Math.round(value)));
    this.radiusKm = normalizedValue;
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.taskListMessage = '';
  }

  applyTaskFilters(): void {
    const typeValue = TASK_ACCEPTANCE_TYPE_FILTER_VALUES[this.faultTypeFilterIndex];
    const severityValue = TASK_ACCEPTANCE_SEVERITY_FILTER_VALUES[this.severityFilterIndex];
    const taskTypeValue = TASK_TYPE_CHIP_VALUES[this.taskTypeFilterIndex];
    this.taskItems = this.allTaskItems.filter((item: TaskAcceptanceItem) => {
      const matchesType = typeValue.length === 0 || item.faultType === typeValue;
      const matchesSeverity = severityValue.length === 0 || item.severity === severityValue;
      const matchesTaskType = taskTypeValue.length === 0 || item.taskType === taskTypeValue;
      return matchesType && matchesSeverity && matchesTaskType;
    });
  }

  resetFilters(): void {
    this.radiusKm = RepairTaskService.getDefaultRadiusKm();
    if (this.radiusKm > this.workloadSnapshot.maxRadiusKm) {
      this.radiusKm = this.workloadSnapshot.maxRadiusKm;
    }
    if (this.radiusKm < 0) {
      this.radiusKm = 0;
    }
    this.taskTypeFilterIndex = 0;
    this.faultTypeFilterIndex = 0;
    this.severityFilterIndex = 0;
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.taskListMessage = '';
    this.acceptActionMessage = '';
    this.acceptActionTaskId = '';
    this.filterResetRevision += 1;
    this.applyTaskFilters();
    this.refreshTasks();
  }

  applyTaskFilterResults(filterResults: FilterResult[]): void {
    filterResults.forEach((item: FilterResult) => {
      if (item.name === '故障类型') {
        this.faultTypeFilterIndex = this.normalizeFilterIndex(item.index, TASK_ACCEPTANCE_TYPE_FILTER_VALUES.length);
      } else if (item.name === '故障等级') {
        this.severityFilterIndex = this.normalizeFilterIndex(item.index, TASK_ACCEPTANCE_SEVERITY_FILTER_VALUES.length);
      } else if (item.name === '任务类型') {
        this.taskTypeFilterIndex = this.normalizeFilterIndex(item.index, TASK_TYPE_CHIP_VALUES.length);
      }
    });
    this.applyTaskFilters();
  }

  getTaskFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('任务类型', TASK_TYPE_CHIP_OPTIONS),
      this.createFilterParams('故障类型', TASK_ACCEPTANCE_TYPE_FILTER_OPTIONS),
      this.createFilterParams('故障等级', TASK_ACCEPTANCE_SEVERITY_FILTER_OPTIONS)
    ];
  }

  createFilterParams(name: string, options: string[]): FilterParams {
    const params: FilterParams = {
      name: name,
      options: options
    };
    return params;
  }

  normalizeFilterIndex(index: number, length: number): number {
    if (index !== index || index < 0) {
      return 0;
    }

    if (index >= length) {
      return length - 1;
    }

    return Math.floor(index);
  }

  applyWorkloadSnapshot(workloadSnapshot: RepairerWorkloadSnapshot): void {
    this.workloadSnapshot = workloadSnapshot;
    if (!workloadSnapshot.canAccept) {
      return;
    }

    if (this.radiusKm > workloadSnapshot.maxRadiusKm) {
      this.radiusKm = workloadSnapshot.maxRadiusKm;
    }

    if (this.radiusKm < 0) {
      this.radiusKm = 0;
    }
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

    return `0-${this.workloadSnapshot.maxRadiusKm} km`;
  }

  isRefreshEnabled(): boolean {
    return !this.refreshing && this.acceptingTaskId.length === 0;
  }

  isTaskAcceptEnabled(item: TaskAcceptanceItem): boolean {
    return this.acceptingTaskId.length === 0 &&
      !this.refreshing &&
      this.workloadSnapshot.canAccept &&
      item.distanceKm !== undefined &&
      item.distanceKm <= this.workloadSnapshot.maxRadiusKm;
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

  formatDistance(item: TaskAcceptanceItem): string {
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
            message: UiFeedbackService.operationUnavailable('刷新')
          },
          timestamp: new Date().toISOString()
        });
      });
    });
  }

  async resolveCurrentLocation(): Promise<LocationResolutionResult> {
    const result = await LocationService.resolveCurrentLocation(this.getUIContext().getHostContext());
    if (result.success && result.coordinates !== undefined) {
      this.hasCurrentLocation = true;
      this.currentLongitude = result.coordinates.longitude;
      this.currentLatitude = result.coordinates.latitude;
      return result;
    }

    this.hasCurrentLocation = false;
    return result;
  }

  findTaskItem(taskId: string): TaskAcceptanceItem | undefined {
    return this.taskItems.find((item: TaskAcceptanceItem) => {
      return item.id === taskId;
    });
  }

  backToOperationsCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'operations/pages/OperationsCenterPage', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}

