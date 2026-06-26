import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { RecordCategory, RecordItem, RecordQueryFilter } from '../../models/management/RecordQueryModels';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { RecordQueryService } from '../../services/management/RecordQueryService';
import { AuthGuard } from '../../utils/AuthGuard';
import { AppNavigator } from '../../utils/AppNavigator';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

const OPERATIONS_RECORD_TYPE_OPTIONS: string[] = ['全部', '核验报告', '报修报告', '任务接取', '维修报告', '复检报告'];
const OPERATIONS_RECORD_TYPE_VALUES: string[] = ['', 'DEVICE_VERIFICATION', 'FAULT_REPORT',
  'REPAIR_TASK_ACCEPT', 'REPAIR_REPORT', 'REINSPECTION_REPORT'];
const RECORD_FILTER_CONTROL_HEIGHT = 56;

@Entry
@Component
struct OperationsRecordQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State records: RecordItem[] = [];
  @State selectedTypeIndex: number = 0;
  @State keyword: string = '';
  @State startDate: string = '';
  @State endDate: string = '';
  @State resultTotal: number = 0;
  @State message: string = '';
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ManagementCenterOperationsRecordQuery)) {
      return;
    }

    this.refreshRecords();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()
        Column({ space: AppSpacing.Section }) {
          this.Header()
          this.RecordListPanel()
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
      Text('运维记录')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Operations Records')
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
    Row({ space: 10 }) {
      this.DateField('开始日期', this.startDate, '请选择开始日期', () => {
        this.showStartDatePicker();
      })
      this.DateField('结束日期', this.endDate, '请选择结束日期', () => {
        this.showEndDatePicker();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  DateField(label: string, value: string, placeholder: string, action: () => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(18)
          .fontColor([value.length > 0 ? AppColors.TextPrimary : AppColors.TextSecondary])

        Text(value.length > 0 ? value : placeholder)
          .fontSize(14)
          .fontColor(value.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
        action();
      })
    }
    .layoutWeight(1)
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
    .width('100%')
    .backgroundColor(this.refreshing ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.refreshing)
    .onClick(() => { this.refreshRecords(); })
  }

  @Builder
  ResultCountText() {
    Text(`共查询到${this.resultTotal}条记录`)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TextSecondary)
      .width('100%')
      .maxLines(1)
  }

  @Builder
  RecordListPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '运维记录列表',
        subtitle: ''
      })

      Column({ space: 14 }) {
        this.SearchPanel()

        Column() {
          Filter({
            multiFilters: this.getRecordFilterParams(),
            onFilterChanged: (filterResults: FilterResult[]) => {
              this.applyRecordFilterResults(filterResults);
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

        this.DateRangePanel()
        this.MessageText()
        this.QueryButton()
        this.ResultCountText()
        this.RecordFilterResultList()
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
  RecordFilterResultList() {
    Column({ space: 12 }) {
      if (this.records.length === 0) {
        this.EmptyState()
      } else {
        ForEach(this.records, (item: RecordItem) => {
          this.OperationsRecordQueryCard(item)
        }, (item: RecordItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  OperationsRecordQueryCard(item: RecordItem) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
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
          Text(item.deviceCode)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(item.statusLabel)
          .fontSize(13)
          .fontColor(RecordQueryService.getStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')

      this.RecordFieldRow('设备编号', item.deviceCode)
      if (item.taskNo.length > 0 && item.taskNo !== '-') {
        this.RecordFieldRow('任务编号', item.taskNo)
      }
      this.RecordFieldRow('操作人', item.operatorName)
      this.RecordFieldRow('时间', item.occurredAt)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
  }

  @Builder
  RecordFieldRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
      Text(value)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
    }
    .width('100%')
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
          .fontSize(36)
          .fontColor([AppColors.Warning])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.WarningSurface)
      Text('暂无运维记录')
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

  async refreshRecords(): Promise<void> {
    if (this.refreshing) { return; }
    if (!this.validateDateRange()) {
      return;
    }
    this.refreshing = true;
    const filter: RecordQueryFilter = {
      category: RecordCategory.Operations,
      type: OPERATIONS_RECORD_TYPE_VALUES[this.selectedTypeIndex],
      keyword: this.keyword,
      startDate: this.startDate,
      endDate: this.endDate,
      page: 1,
      pageSize: 50
    };
    const response = await RecordQueryService.queryRecords(filter);
    this.refreshing = false;
    if (!response.success) {
      this.message = UiFeedbackService.operationError(response.error, '查询');
      return;
    }
    this.records = response.data ? response.data.items : [];
    this.resultTotal = response.data ? response.data.total : 0;
    this.message = '';
  }

  applyRecordFilterResults(filterResults: FilterResult[]): void {
    const result = filterResults.find((item: FilterResult) => {
      return item.name === '记录类型';
    });
    this.selectedTypeIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, OPERATIONS_RECORD_TYPE_VALUES.length);
    this.refreshRecords();
  }

  getRecordFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('记录类型', OPERATIONS_RECORD_TYPE_OPTIONS)
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
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/ManagementCenter/RecordQuery', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
