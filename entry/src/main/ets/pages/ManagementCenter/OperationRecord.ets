import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OperationRecordQueryFilter, OperationRecordSummary } from '../../models/OperationRecordModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { OperationRecordService } from '../../services/OperationRecordService';
import { AuthGuard } from '../../utils/AuthGuard';

const OPERATION_ACTION_LABELS: string[] = [
  '全部记录',
  '二维码导出',
  '档案变更申请',
  '档案审核',
  '设备核验',
  '设备报修',
  '维修接取',
  '维修报告',
  '复检记录',
  '离线同步',
  '登录',
  '密码复核',
  '权限拦截'
];

const OPERATION_ACTION_VALUES: string[] = [
  '',
  'DEVICE_QRCODE_EXPORT',
  'DEVICE_CHANGE_REQUEST',
  'DEVICE_CHANGE_REVIEW',
  'DEVICE_VERIFICATION',
  'FAULT_REPORT',
  'REPAIR_TASK_ACCEPT',
  'REPAIR_REPORT',
  'REINSPECTION_RECORD',
  'OFFLINE_SYNC',
  'AUTH_LOGIN',
  'AUTH_PASSWORD_VERIFY',
  'AUTHORIZATION_DENIED'
];

@Entry
@Component
struct OperationRecord {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State records: OperationRecordSummary[] = [];
  @State totalRecords: number = 0;
  @State message: string = '';
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;
  @State selectedActionIndex: number = 0;
  @State keyword: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.MgmtAuditLogRead)) {
      return;
    }

    this.refreshRecords();
  }

  onPageShow(): void {
    if (AuthGuard.requirePermission(this.getUIContext(), PermissionCode.MgmtAuditLogRead)) {
      this.refreshRecords();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.FilterPanel()
          this.RecordListPanel()
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
      Text('操作记录')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('查看关键业务流转记录')
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
    Column({ space: 12 }) {
      Text('筛选条件')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column({ space: 12 }) {
        Filter({
          multiFilters: this.getOperationFilterParams(),
          onFilterChanged: (filterResults: FilterResult[]) => {
            this.applyOperationFilterResults(filterResults);
          },
          filterType: FilterType.MULTI_LINE_FILTER
        }) {
          Blank()
            .height(0)
        }

        this.FieldTitle('关键词')

        TextInput({
          placeholder: '输入设备编号、操作人或说明关键词',
          text: this.keyword
        })
          .height(52)
          .fontSize(15)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.keyword = value;
            this.message = '';
          })

        this.MessageText()

        Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(17)
              .fontColor([this.refreshing ? AppColors.TextSecondary : AppColors.OnPrimary])

            Text(this.refreshing ? '查询中' : '查询记录')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.refreshing ? AppColors.TextSecondary : AppColors.OnPrimary)
              .maxLines(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .height(46)
        .width('100%')
        .backgroundColor(this.refreshing ? AppColors.FieldBackground : AppColors.Primary)
        .enabled(!this.refreshing)
        .onClick(() => {
          this.refreshRecords();
        })
      }
      .padding({
        left: 18,
        right: 18,
        top: 14,
        bottom: 18
      })
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  RecordListPanel() {
    Column({ space: 10 }) {
      Text(this.hasActiveFilter() ? '筛选结果' : '最近记录')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      if (this.records.length === 0) {
        this.EmptyState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.records, (item: OperationRecordSummary) => {
            this.RecordItem(item)
          }, (item: OperationRecordSummary) => item.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.text_clipboard'))
          .fontSize(36)
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无操作记录')
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
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecordItem(item: OperationRecordSummary) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.text_clipboard'))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(OperationRecordService.getRecordStatusTone(item.status))

        Column({ space: 4 }) {
          Text(item.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.targetNo)
            .fontSize(12)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(OperationRecordService.formatRecordStatus(item.status))
          .fontSize(13)
          .fontColor(OperationRecordService.getRecordStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(OperationRecordService.formatRecordType(item.type))
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)

        Text(item.occurredAt)
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
      }
      .width('100%')

      Row() {
        Text('操作人')
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)

        Text(item.operatorName)
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Text(item.description)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .lineHeight(19)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        StatusInfoRow({ label: '记录数量', value: this.getRecordCountText(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '刷新状态',
          value: this.message.length > 0 ? '刷新失败' : this.refreshStatus,
          tone: this.message.length > 0 ? AppColors.Danger : AppColors.Success
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
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
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

  async refreshRecords(): Promise<void> {
    if (this.refreshing) {
      return;
    }

    this.refreshing = true;
    const response = await OperationRecordService.queryRecentRecordsRemoteFirst(this.createCurrentFilter());
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '操作记录刷新失败';
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    this.records = data ? data.items : [];
    this.totalRecords = data ? data.total : this.records.length;
    this.message = '';
    this.refreshStatus = '已刷新';
  }

  applyOperationFilterResults(filterResults: FilterResult[]): void {
    if (filterResults.length === 0) {
      this.selectedActionIndex = 0;
      this.message = '';
      return;
    }

    const actionResult = filterResults.find((item: FilterResult) => {
      return item.name === '操作类型';
    });
    if (actionResult === undefined) {
      return;
    }

    this.selectedActionIndex = this.normalizeFilterIndex(actionResult.index, OPERATION_ACTION_VALUES.length);
    this.message = '';
  }

  getOperationFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('操作类型', OPERATION_ACTION_LABELS)
    ];
  }

  createFilterParams(name: string, options: string[]): FilterParams {
    const params = new FilterParams();
    params.name = name;
    params.options = options;
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

  createCurrentFilter(): OperationRecordQueryFilter {
    return {
      action: OPERATION_ACTION_VALUES[this.selectedActionIndex],
      keyword: this.keyword.trim()
    };
  }

  hasActiveFilter(): boolean {
    return OPERATION_ACTION_VALUES[this.selectedActionIndex].length > 0 || this.keyword.trim().length > 0;
  }

  getRecordCountText(): string {
    if (this.totalRecords > this.records.length) {
      return `${this.records.length}/${this.totalRecords}条`;
    }

    return `${this.records.length}条`;
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
