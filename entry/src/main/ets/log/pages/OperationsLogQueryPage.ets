import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { PermissionCode } from '../../user/models/PermissionModels';
import { LogCategory, LogItem, LogQueryFilter, LogQueryTab } from '../models/LogQueryModels';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { LogQueryService } from '../services/LogQueryService';
import { SessionStore } from '../../user/stores/SessionStore';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';

const RECORD_FILTER_CONTROL_HEIGHT = 56;

@Entry
@Component
struct OperationsLogQueryPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State logs: LogItem[] = [];
  @State currentTab: LogQueryTab = LogQueryTab.Operation;
  @State currentTabIndex: number = 0;
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
    this.refreshLogs(this.currentTab);
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentTabIndex
    }) {
      TabContent() {
        this.LogQueryTabContent(LogQueryTab.Operation)
      }
      .tabBar(this.TabBarItem('操作日志', $r('sys.symbol.wrench_and_screwdriver'), LogQueryTab.Operation,
        this.canQueryOperationsOperationLog()))

      TabContent() {
        this.LogQueryTabContent(LogQueryTab.Review)
      }
      .tabBar(this.TabBarItem('审核日志', $r('sys.symbol.checkmark_shield'), LogQueryTab.Review,
        this.canQueryOperationsReviewLog()))
    }
    .barMode(BarMode.Fixed)
    .barHeight(78)
    .scrollable(false)
    .onChange((index: number) => {
      this.switchTab(this.getTabFromIndex(index));
    })
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  LogQueryTabContent(tab: LogQueryTab) {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.Header(tab)
          this.LogListPanel(tab)
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
  Header(tab: LogQueryTab) {
    Column({ space: 5 }) {
      Text(this.getPageTitle(tab))
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.getPageSubtitle(tab))
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
  TabBarItem(label: string, icon: Resource, tab: LogQueryTab, enabled: boolean) {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([this.getTabIconColor(tab, enabled)])

      Text(label)
        .fontSize(12)
        .fontWeight(this.currentTab === tab ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.getTabLabelColor(tab, enabled))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(62)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .opacity(enabled ? 1 : 0.45)
    .enabled(enabled)
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
  QueryButton(tab: LogQueryTab) {
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
    .onClick(() => { this.refreshLogs(tab); })
  }

  @Builder
  ResetButton(tab: LogQueryTab) {
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
      this.resetFilters(tab);
    })
  }

  @Builder
  ActionButtons(tab: LogQueryTab) {
    Row({ space: 10 }) {
      this.ResetButton(tab)
      this.QueryButton(tab)
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
  LogListPanel(tab: LogQueryTab) {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: this.getListTitle(tab),
        subtitle: ''
      })

      Column({ space: 14 }) {
        this.SearchPanel()

        this.LogTypeFilterControl(tab)

        this.DateRangePanel()
        this.MessageText()
        this.ActionButtons(tab)
        this.ResultCountText()
        this.LogFilterResultList(tab)
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
  LogTypeFilterControl(tab: LogQueryTab) {
    if (this.filterResetRevision % 2 === 0) {
      this.LogTypeFilterInstance(tab)
    } else {
      this.LogTypeFilterInstance(tab)
    }
  }

  @Builder
  LogTypeFilterInstance(tab: LogQueryTab) {
    Column() {
      Filter({
        multiFilters: this.getLogFilterParams(tab),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyLogFilterResults(tab, filterResults);
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
  LogFilterResultList(tab: LogQueryTab) {
    Column({ space: 12 }) {
      if (this.logs.length === 0) {
        this.EmptyState(tab)
      } else {
        ForEach(this.logs, (item: LogItem) => {
          this.OperationsLogQueryCard(item, tab)
        }, (item: LogItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  OperationsLogQueryCard(item: LogItem, tab: LogQueryTab) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph(this.getLogIconForTab(tab))
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
  EmptyState(tab: LogQueryTab) {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph(this.getLogIconForTab(tab))
          .fontSize(36)
          .fontColor([AppColors.Warning])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.WarningSurface)
      Text(this.getEmptyTextForTab(tab))
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

  async refreshLogs(tab: LogQueryTab = this.currentTab): Promise<void> {
    if (this.refreshing) { return; }
    if (!this.validateDateRange()) {
      return;
    }
    this.refreshing = true;
    const typeValues = this.getTypeValuesForTab(tab);
    const filter: LogQueryFilter = {
      category: this.getCategoryForTab(tab),
      type: typeValues[this.normalizeFilterIndex(this.selectedTypeIndex, typeValues.length)],
      keyword: this.keyword,
      startDate: this.startDate,
      endDate: this.endDate,
      page: 1,
      pageSize: 50
    };
    const response = await LogQueryService.queryLogs(filter);
    this.refreshing = false;
    if (this.currentTab !== tab) {
      this.refreshLogs(this.currentTab);
      return;
    }

    if (!response.success) {
      this.message = UiFeedbackService.operationError(response.error, '查询');
      return;
    }
    this.logs = response.data ? response.data.items : [];
    this.resultTotal = response.data ? response.data.total : 0;
    this.message = '';
  }

  resetFilters(tab: LogQueryTab = this.currentTab): void {
    this.selectedTypeIndex = 0;
    this.keyword = '';
    this.startDate = '';
    this.endDate = '';
    this.message = '';
    this.filterResetRevision += 1;
    this.refreshLogs(tab);
  }

  applyLogFilterResults(tab: LogQueryTab, filterResults: FilterResult[]): void {
    if (this.currentTab !== tab) {
      return;
    }

    const result = filterResults.find((item: FilterResult) => {
      return item.name === '日志类型';
    });
    this.selectedTypeIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, this.getTypeValuesForTab(tab).length);
    this.refreshLogs(tab);
  }

  getLogFilterParams(tab: LogQueryTab): FilterParams[] {
    return [
      this.createFilterParams('日志类型', this.getTypeOptionsForTab(tab))
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
      this.currentTabIndex = this.getTabIndex(tab);
      return;
    }

    if (tab === LogQueryTab.Operation && !this.canQueryOperationsOperationLog()) {
      this.currentTabIndex = this.getTabIndex(this.currentTab);
      return;
    }

    if (tab === LogQueryTab.Review && !this.canQueryOperationsReviewLog()) {
      this.currentTabIndex = this.getTabIndex(this.currentTab);
      return;
    }

    this.currentTab = tab;
    this.currentTabIndex = this.getTabIndex(tab);
    this.logs = [];
    this.resultTotal = 0;
    this.resetFilters(tab);
  }

  ensureAvailableTab(): void {
    if (this.currentTab === LogQueryTab.Operation && this.canQueryOperationsOperationLog()) {
      this.currentTabIndex = this.getTabIndex(this.currentTab);
      return;
    }

    if (this.currentTab === LogQueryTab.Review && this.canQueryOperationsReviewLog()) {
      this.currentTabIndex = this.getTabIndex(this.currentTab);
      return;
    }

    this.currentTab = this.canQueryOperationsOperationLog() ? LogQueryTab.Operation : LogQueryTab.Review;
    this.currentTabIndex = this.getTabIndex(this.currentTab);
  }

  canQueryOperationsOperationLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterOperationsOperationLogQuery);
  }

  canQueryOperationsReviewLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterOperationsReviewLogQuery);
  }

  getPageTitle(tab: LogQueryTab): string {
    return LogQueryService.formatPageTitle(this.getCategoryForTab(tab));
  }

  getPageSubtitle(tab: LogQueryTab): string {
    return LogQueryService.formatPageSubtitle(this.getCategoryForTab(tab));
  }

  getListTitle(tab: LogQueryTab): string {
    return LogQueryService.formatListTitle(this.getCategoryForTab(tab));
  }

  getEmptyTextForTab(tab: LogQueryTab): string {
    return tab === LogQueryTab.Review ? '暂无运维审核日志' : '暂无运维操作日志';
  }

  getLogIconForTab(tab: LogQueryTab): Resource {
    return tab === LogQueryTab.Review ? $r('sys.symbol.checkmark_shield') :
      $r('sys.symbol.wrench_and_screwdriver');
  }

  getTypeOptionsForTab(tab: LogQueryTab): string[] {
    return LogQueryService.getOperationsLogTypeOptions(tab);
  }

  getTypeValuesForTab(tab: LogQueryTab): string[] {
    return LogQueryService.getOperationsLogTypeValues(tab);
  }

  getCategoryForTab(tab: LogQueryTab): LogCategory {
    return LogQueryService.resolveOperationsCategory(tab);
  }

  getTabIndex(tab: LogQueryTab): number {
    return tab === LogQueryTab.Review ? 1 : 0;
  }

  getTabFromIndex(index: number): LogQueryTab {
    return index === 1 ? LogQueryTab.Review : LogQueryTab.Operation;
  }

  getTabIconColor(tab: LogQueryTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Log : AppColors.TextTertiary;
  }

  getTabLabelColor(tab: LogQueryTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Log : AppColors.TextSecondary;
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
    AppNavigator.backOrReplace(this.getUIContext(), 'log/pages/LogCenterPage', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
