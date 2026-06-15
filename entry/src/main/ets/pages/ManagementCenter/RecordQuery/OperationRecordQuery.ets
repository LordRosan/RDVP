import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors } from '../../../styles/AppTheme';
import { RecordCategory, RecordItem, RecordQueryFilter } from '../../../models/management/RecordQueryModels';
import { RecordQueryService } from '../../../services/management/RecordQueryService';

const OPERATION_RECORD_TYPE_OPTIONS: string[] = ['全部', '核验', '报修', '接取', '维修', '复检'];
const OPERATION_RECORD_TYPE_VALUES: string[] = ['', 'DEVICE_VERIFICATION', 'FAULT_REPORT',
  'REPAIR_TASK_ACCEPT', 'REPAIR_REPORT', 'REINSPECTION_RECORD'];

@Entry
@Component
struct OperationRecordQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State records: RecordItem[] = [];
  @State selectedTypeIndex: number = 0;
  @State keyword: string = '';
  @State message: string = '';
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    this.refreshRecords();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()
        Column({ space: 18 }) {
          this.ModeHeader()
          this.SearchPanel()
          this.RecordListPanel()
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24, right: 24, top: 0, bottom: 28 })
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Start)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
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
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => { this.backToParent(); })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Text('运维记录')
      .fontSize(34)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
      .width('100%')
      .padding({ top: 0, bottom: 2 })
  }

  @Builder
  SearchPanel() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '输入设备编号或操作人搜索', text: this.keyword })
        .height(52)
        .fontSize(15)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .onChange((value: string) => { this.keyword = value; })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor(AppColors.Danger)
          .maxLines(2)
          .width('100%')
      }

      Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(17)
            .fontColor([this.refreshing ? AppColors.TextSecondary : AppColors.OnPrimary])
          Text(this.refreshing ? '查询中' : '查询记录')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.refreshing ? AppColors.TextSecondary : AppColors.OnPrimary)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .height(46)
      .width('100%')
      .backgroundColor(this.refreshing ? AppColors.FieldBackground : AppColors.Primary)
      .enabled(!this.refreshing)
      .onClick(() => { this.refreshRecords(); })
    }
    .width('100%')
  }

  @Builder
  RecordListPanel() {
    Column({ space: 12 }) {
      Filter({
        multiFilters: this.getRecordFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyRecordFilterResults(filterResults);
        },
        filterType: FilterType.LIST_FILTER
      }) {
        Column({ space: 12 }) {
          this.RecordFilterResultList()
          this.ResultSummaryPanel()
        }
      }
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
          this.OperationRecordQueryCard(item)
        }, (item: RecordItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  OperationRecordQueryCard(item: RecordItem) {
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

      this.RecordFieldRow('设备标准编号', item.deviceCode)
      if (item.taskNo.length > 0 && item.taskNo !== '-') {
        this.RecordFieldRow('标准任务编号', item.taskNo)
      }
      this.RecordFieldRow('操作人', item.operatorName)
      this.RecordFieldRow('时间', item.occurredAt)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
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
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)
      Text('暂无运维记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 28, bottom: 28 })
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ResultSummaryPanel() {
    Column() {
      this.RecordFieldRow('记录数量', `${this.records.length}条`)
      Divider()
        .height(1)
        .backgroundColor(AppColors.Divider)
        .margin({ left: 18, right: 18 })
      this.RecordFieldRow('筛选类型', OPERATION_RECORD_TYPE_OPTIONS[this.selectedTypeIndex])
    }
    .width('100%')
    .padding({ left: 18, right: 18 })
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  async refreshRecords(): Promise<void> {
    if (this.refreshing) { return; }
    this.refreshing = true;
    const filter: RecordQueryFilter = {
      category: RecordCategory.Operations,
      type: OPERATION_RECORD_TYPE_VALUES[this.selectedTypeIndex],
      keyword: this.keyword,
      page: 1,
      pageSize: 50
    };
    const response = await RecordQueryService.queryRecords(filter);
    this.refreshing = false;
    if (!response.success) {
      this.message = response.error ? response.error.message : '查询失败';
      return;
    }
    this.records = response.data ? response.data.items : [];
    this.message = '';
  }

  applyRecordFilterResults(filterResults: FilterResult[]): void {
    const result = filterResults.find((item: FilterResult) => {
      return item.name === '记录类型';
    });
    this.selectedTypeIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, OPERATION_RECORD_TYPE_VALUES.length);
    this.refreshRecords();
  }

  getRecordFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('记录类型', OPERATION_RECORD_TYPE_OPTIONS)
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

  backToParent(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) { router.back(); return; }
      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
    }
  }
}
