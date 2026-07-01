import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import {
  LogQueryBottomContentPadding,
  LogQueryTab,
  LogQueryTabBar
} from '../../components/LogQueryTabBar';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { LogCategory, LogItem, LogQueryFilter } from '../../models/log/LogQueryModels';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { LogQueryService } from '../../services/log/LogQueryService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { AppNavigator } from '../../utils/AppNavigator';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

const OPERATIONS_OPERATION_TYPE_OPTIONS: string[] = ['全部', '核验报告', '报修报告', '任务接取', '维修报告', '复检报告'];
const OPERATIONS_OPERATION_TYPE_VALUES: string[] = ['', 'DEVICE_VERIFICATION', 'FAULT_REPORT',
  'REPAIR_TASK_ACCEPT', 'REPAIR_REPORT', 'REINSPECTION_REPORT'];
const OPERATIONS_REVIEW_TYPE_OPTIONS: string[] = ['全部', '核验报告', '报修报告', '维修报告', '复检报告'];
const OPERATIONS_REVIEW_TYPE_VALUES: string[] = ['', 'DEVICE_VERIFICATION_REPORT', 'FAULT_REPORT',
  'REPAIR_REPORT', 'REINSPECTION_REPORT'];
const RECORD_FILTER_CONTROL_HEIGHT = 56;

@Entry
@Component
struct OperationsLogQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State logs: LogItem[] = [];
  @State currentTab: LogQueryTab = LogQueryTab.Operation;
  @State selectedTypeIndex: number = 0;
  @State keyword: string = '';
  @State startDate: string = '';
  @State endDate: string = '';
  @State resultTotal: number = 0;
  @State message: string = '';
  @State refreshing: boolean = false;
  @State filterResetRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), [
      PermissionCode.LogCenterOperationsOperationLogQuery,
      PermissionCode.LogCenterOperationsReviewLogQuery
    ])) {
      return;
    }

    this.ensureAvailableTab();
    this.refreshLogs();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          this.PageTitleBar()
          Column({ space: AppSpacing.Section }) {
            this.Header()
            this.LogListPanel()
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .padding({
            left: AppSpacing.PageX,
            right: AppSpacing.PageX,
            top: 0,
            bottom: LogQueryBottomContentPadding
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

      LogQueryTabBar({
        currentTab: this.currentTab,
        operationEnabled: this.canQueryOperationsOperationLog(),
        reviewEnabled: this.canQueryOperationsReviewLog(),
        onOperationClick: () => {
          this.switchTab(LogQueryTab.Operation);
        },
        onReviewClick: () => {
          this.switchTab(LogQueryTab.Review);
        }
      })
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToParent();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text(this.getPageTitle())
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Operations Logs')
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
  SearchPanel() {
    TextInput({ placeholder: '请输入设备编号或操作人进行搜索', text: this.keyword })
      .height(52)
      .fontSize(15)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .border({ width: 1, color: AppColors.Border })
      .onChange((value: string) => { this.keyword = value; })
      .width('100%')
  }

  @Builder
  DateRangePanel() {
    Column({ space: 10 }) {
      this.StartDateField()
      this.EndDateField()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StartDateField() {
    Column({ space: 8 }) {
      Text('开始日期')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(18)
          .fontColor([this.startDate.length > 0 ? AppColors.TextPrimary : AppColors.TextSecondary])

        Text(this.startDate.length > 0 ? this.startDate : '请选择开始日期')
          .fontSize(14)
          .fontColor(this.startDate.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(52)
      .width('100%')
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 14, right: 14 })
      .border({ width: 1, color: AppColors.Border })
      .onClick(() => {
        this.showStartDatePicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EndDateField() {
    Column({ space: 8 }) {
      Text('结束日期')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(18)
          .fontColor([this.endDate.length > 0 ? AppColors.TextPrimary : AppColors.TextSecondary])

        Text(this.endDate.length > 0 ? this.endDate : '请选择结束日期')
          .fontSize(14)
          .fontColor(this.endDate.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(52)
      .width('100%')
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 14, right: 14 })
      .border({ width: 1, color: AppColors.Border })
      .onClick(() => {
        this.showEndDatePicker();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QueryButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(17)
          .fontColor([AppColors.OnPrimary])
        Text(this.refreshing ? '查询中' : '查询')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .layoutWeight(1)
    .backgroundColor(this.refreshing ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.refreshing)
    .onClick(() => { this.refreshLogs(); })
  }

  @Builder
  ResetButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.xmark_circle'))
          .fontSize(17)
          .fontColor([AppColors.TextPrimary])
        Text('重置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .layoutWeight(1)
    .backgroundColor(AppColors.FieldBackground)
    .border({ width: 1, color: AppColors.Border })
    .enabled(!this.refreshing)
    .onClick(() => {
      this.resetFilters();
    })
  }

  @Builder
  ActionButtons() {
    Row({ space: 10 }) {
      this.ResetButton()
      this.QueryButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ResultCountText() {
    Text(`共查询到${this.resultTotal}条日志`)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TextSecondary)
      .width('100%')
      .maxLines(1)
  }

  @Builder
  LogListPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: this.getListTitle(),
        subtitle: ''
      })

      Column({ space: 14 }) {
        this.SearchPanel()

        this.LogTypeFilterControl()

        this.DateRangePanel()
        this.MessageText()
        this.ActionButtons()
        this.ResultCountText()
        this.LogFilterResultList()
      }
      .width('100%')
      .padding({
        left: 18,
        right: 18,
        top: 18,
        bottom: 18
      })
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LogTypeFilterControl() {
    if (this.filterResetRevision % 2 === 0) {
      this.LogTypeFilterInstance()
    } else {
      this.LogTypeFilterInstance()
    }
  }

  @Builder
  LogTypeFilterInstance() {
    Column() {
      Filter({
        multiFilters: this.getLogFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyLogFilterResults(filterResults);
        },
        filterType: FilterType.LIST_FILTER
      }) {
        Column()
          .width('100%')
          .height(1)
      }
    }
    .height(RECORD_FILTER_CONTROL_HEIGHT)
    .width('100%')
    .clip(true)
  }

  @Builder
  LogFilterResultList() {
    Column({ space: 12 }) {
      if (this.logs.length === 0) {
        this.EmptyState()
      } else {
        ForEach(this.logs, (item: LogItem) => {
          this.OperationsLogQueryCard(item)
        }, (item: LogItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  OperationsLogQueryCard(item: LogItem) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph(this.getCurrentLogIcon())
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(AppColors.Primary)
        Column({ space: 4 }) {
          Text(item.typeLabel)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(item.statusLabel)
          .fontSize(13)
          .fontColor(LogQueryService.getStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')

      this.LogFieldRow('设备编号', item.deviceCode)
      if (item.taskNo.length > 0 && item.taskNo !== '-') {
        this.LogFieldRow('任务编号', item.taskNo)
      }
      this.LogFieldRow('操作人', item.operatorName)
      this.LogFieldRow('时间', item.occurredAt)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
  }

  @Builder
  LogFieldRow(label: string, value: string, tone: string = AppColors.TextSecondary) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
      Text(value)
        .fontSize(13)
        .fontColor(tone)
        .maxLines(1)
    }
    .width('100%')
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph(this.getCurrentLogIcon())
          .fontSize(36)
          .fontColor([AppColors.Warning])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.WarningSurface)
      Text(this.getEmptyText())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 28, bottom: 28 })
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: UiFeedbackTone.Danger
      })
    }
  }

  async refreshLogs(): Promise<void> {
    if (this.refreshing) { return; }
    if (!this.validateDateRange()) {
      return;
    }
    this.refreshing = true;
    const typeValues = this.getCurrentTypeValues();
    const filter: LogQueryFilter = {
      category: this.getCurrentCategory(),
      type: typeValues[this.normalizeFilterIndex(this.selectedTypeIndex, typeValues.length)],
      keyword: this.keyword,
      startDate: this.startDate,
      endDate: this.endDate,
      page: 1,
      pageSize: 50
    };
    const response = await LogQueryService.queryLogs(filter);
    this.refreshing = false;
    if (!response.success) {
      this.message = UiFeedbackService.operationError(response.error, '查询');
      return;
    }
    this.logs = response.data ? response.data.items : [];
    this.resultTotal = response.data ? response.data.total : 0;
    this.message = '';
  }

  resetFilters(): void {
    this.selectedTypeIndex = 0;
    this.keyword = '';
    this.startDate = '';
    this.endDate = '';
    this.message = '';
    this.filterResetRevision += 1;
    this.refreshLogs();
  }

  applyLogFilterResults(filterResults: FilterResult[]): void {
    const result = filterResults.find((item: FilterResult) => {
      return item.name === '日志类型';
    });
    this.selectedTypeIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, this.getCurrentTypeValues().length);
    this.refreshLogs();
  }

  getLogFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('日志类型', this.getCurrentTypeOptions())
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

  switchTab(tab: LogQueryTab): void {
    if (this.currentTab === tab) {
      return;
    }

    if (tab === LogQueryTab.Operation && !this.canQueryOperationsOperationLog()) {
      return;
    }

    if (tab === LogQueryTab.Review && !this.canQueryOperationsReviewLog()) {
      return;
    }

    this.currentTab = tab;
    this.logs = [];
    this.resultTotal = 0;
    this.resetFilters();
  }

  ensureAvailableTab(): void {
    if (this.currentTab === LogQueryTab.Operation && this.canQueryOperationsOperationLog()) {
      return;
    }

    if (this.currentTab === LogQueryTab.Review && this.canQueryOperationsReviewLog()) {
      return;
    }

    this.currentTab = this.canQueryOperationsOperationLog() ? LogQueryTab.Operation : LogQueryTab.Review;
  }

  canQueryOperationsOperationLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterOperationsOperationLogQuery);
  }

  canQueryOperationsReviewLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterOperationsReviewLogQuery);
  }

  getCurrentCategory(): LogCategory {
    return this.currentTab === LogQueryTab.Review ? LogCategory.OperationsReview : LogCategory.OperationsOperation;
  }

  getCurrentTypeOptions(): string[] {
    return this.currentTab === LogQueryTab.Review ? OPERATIONS_REVIEW_TYPE_OPTIONS : OPERATIONS_OPERATION_TYPE_OPTIONS;
  }

  getCurrentTypeValues(): string[] {
    return this.currentTab === LogQueryTab.Review ? OPERATIONS_REVIEW_TYPE_VALUES : OPERATIONS_OPERATION_TYPE_VALUES;
  }

  getPageTitle(): string {
    return LogQueryService.formatPageTitle(this.getCurrentCategory());
  }

  getListTitle(): string {
    return LogQueryService.formatListTitle(this.getCurrentCategory());
  }

  getEmptyText(): string {
    return this.currentTab === LogQueryTab.Review ? '暂无运维审核日志' : '暂无运维操作日志';
  }

  getCurrentLogIcon(): Resource {
    return this.currentTab === LogQueryTab.Review ? $r('sys.symbol.checkmark_shield') :
      $r('sys.symbol.wrench_and_screwdriver');
  }

  showStartDatePicker(): void {
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1),
      end: this.endDate.length > 0 ? this.resolveSelectedDate(this.endDate) : new Date(),
      selected: this.startDate.length > 0 ? this.resolveSelectedDate(this.startDate) :
        (this.endDate.length > 0 ? this.resolveSelectedDate(this.endDate) : new Date()),
      showTime: false,
      onDateAccept: (value: Date) => {
        this.startDate = this.formatDate(value);
        this.message = '';
      }
    });
  }

  showEndDatePicker(): void {
    this.getUIContext().showDatePickerDialog({
      start: this.startDate.length > 0 ? this.resolveSelectedDate(this.startDate) : new Date(2000, 0, 1),
      end: new Date(),
      selected: this.resolveSelectedDate(this.endDate),
      showTime: false,
      onDateAccept: (value: Date) => {
        this.endDate = this.formatDate(value);
        this.message = '';
      }
    });
  }

  validateDateRange(): boolean {
    if (this.endDate.length > 0 && this.resolveSelectedDate(this.endDate).getTime() > this.todayStart().getTime()) {
      this.message = '结束日期不能晚于今天';
      return false;
    }

    if (this.startDate.length > 0 && this.endDate.length > 0 &&
      this.resolveSelectedDate(this.startDate).getTime() > this.resolveSelectedDate(this.endDate).getTime()) {
      this.message = '开始日期不能晚于结束日期';
      return false;
    }

    return true;
  }

  resolveSelectedDate(value: string): Date {
    const segments = value.trim().split('-');
    if (segments.length !== 3) {
      return this.todayStart();
    }

    const year = Number(segments[0]);
    const month = Number(segments[1]);
    const day = Number(segments[2]);
    if (year !== year || month !== month || day !== day) {
      return this.todayStart();
    }

    return new Date(year, month - 1, day);
  }

  todayStart(): Date {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  formatDate(value: Date): string {
    return `${value.getFullYear()}-${this.pad2(value.getMonth() + 1)}-${this.pad2(value.getDate())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  backToParent(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/LogCenter/LogCenter', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
