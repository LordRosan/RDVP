import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { RecordCategory, RecordItem, RecordQueryFilter } from '../../models/management/RecordQueryModels';
import { RecordQueryService } from '../../services/management/RecordQueryService';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

const REVIEW_TYPE_OPTIONS: string[] = ['全部', '添加档案', '修改档案', '删除档案', '维修报告', '复检报告'];
const REVIEW_TYPE_VALUES: string[] = ['', 'CREATE', 'UPDATE', 'DELETE', 'REPAIR_REPORT', 'REINSPECTION_REPORT'];
const RECORD_FILTER_CONTROL_HEIGHT = 56;

@Entry
@Component
struct ReviewRecordQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State records: RecordItem[] = [];
  @State selectedTypeIndex: number = 0;
  @State keyword: string = '';
  @State message: string = '';
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ManagementCenterReviewRecordQuery)) {
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

  onBackPress(): boolean {
    this.backToParent();
    return true;
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
      Text('审核记录')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Review Records')
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
    TextInput({ placeholder: '输入设备编号或操作人搜索', text: this.keyword })
      .height(52)
      .fontSize(15)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .border({ width: 1, color: AppColors.Border })
      .onChange((value: string) => {
        this.keyword = value;
      })
      .width('100%')
  }

  @Builder
  QueryButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(17)
          .fontColor([AppColors.OnPrimary])
        Text(this.refreshing ? '查询中' : '查询记录')
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
    .onClick(() => {
      this.refreshRecords();
    })
  }

  @Builder
  RecordListPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '审核记录列表',
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

        this.MessageText()
        this.QueryButton()
        this.RecordFilterResultList()
        this.ResultSummaryPanel()
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
          this.ReviewRecordQueryCard(item)
        }, (item: RecordItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  ReviewRecordQueryCard(item: RecordItem) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.checkmark_shield'))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(RecordQueryService.getStatusTone(item.status))

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
      this.RecordFieldRow('审核编号', item.taskNo)
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
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(36)
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)
      Text('暂无审核记录')
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
  ResultSummaryPanel() {
    Column() {
      this.RecordFieldRow('记录数量', `${this.records.length}条`)
      this.CardDivider()
      this.RecordFieldRow('筛选类型', REVIEW_TYPE_OPTIONS[this.selectedTypeIndex])
    }
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({ left: 18, right: 18 })
  }

  async refreshRecords(): Promise<void> {
    if (this.refreshing) {
      return;
    }

    this.refreshing = true;
    const filter: RecordQueryFilter = {
      category: RecordCategory.Review,
      type: REVIEW_TYPE_VALUES[this.selectedTypeIndex],
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
      this.normalizeFilterIndex(result.index, REVIEW_TYPE_VALUES.length);
    this.refreshRecords();
  }

  getRecordFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('记录类型', REVIEW_TYPE_OPTIONS)
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
    if (!MainPageNavigator.backOrReplace(this.getUIContext(), 'pages/ManagementCenter/RecordQuery')) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
