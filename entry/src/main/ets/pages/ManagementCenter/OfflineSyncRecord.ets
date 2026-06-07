import { Filter, FilterType } from '@kit.ArkUI';
import type { FilterParams, FilterResult } from '@kit.ArkUI';
import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OfflineSyncRecordLogSummary } from '../../models/OfflineSyncRecordLogModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { OfflineSyncRecordLogService } from '../../services/OfflineSyncRecordLogService';
import { AuthGuard } from '../../utils/AuthGuard';

const SYNC_RECORD_STATUS_FILTER_OPTIONS: string[] = ['全部状态', '已同步', '同步失败'];
const SYNC_RECORD_STATUS_FILTER_VALUES: string[] = ['', 'SUCCEEDED', 'FAILED'];
const SYNC_RECORD_TYPE_FILTER_OPTIONS: string[] = ['全部类型', '设备核验与报修', '设备核验', '故障报告', '档案新增申请', '档案变更申请', '档案删除申请'];
const SYNC_RECORD_TYPE_FILTER_VALUES: string[] = ['', 'DEVICE_VERIFICATION_FAULT_REPORT_CREATE',
  'DEVICE_VERIFICATION_CREATE', 'FAULT_REPORT_CREATE', 'DEVICE_ARCHIVE_CREATE_REQUEST_CREATE',
  'DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE', 'DEVICE_ARCHIVE_DELETE_REQUEST_CREATE'];

@Entry
@Component
struct OfflineSyncRecord {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State allRecords: OfflineSyncRecordLogSummary[] = [];
  @State records: OfflineSyncRecordLogSummary[] = [];
  @State totalRecords: number = 0;
  @State message: string = '';
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;
  @State statusFilterIndex: number = 0;
  @State typeFilterIndex: number = 0;

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
    this.backToManagementCenter();
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
        this.backToManagementCenter();
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
      Text('同步处理记录')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('在线查看离线内容提交后的服务端处理结果')
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
  RecordListPanel() {
    Column({ space: 10 }) {
      this.MessageText()

      Row() {
        Text('最近同步记录')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .backgroundColor(this.refreshing ? AppColors.Disabled : AppColors.Primary)
        .enabled(!this.refreshing)
        .onClick(() => {
          this.refreshRecords();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Filter({
        multiFilters: this.getRecordFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyRecordFilterResults(filterResults);
        },
        filterType: FilterType.MULTI_LINE_FILTER
      }) {
        Blank()
          .height(0)
      }

      if (this.records.length === 0) {
        this.EmptyState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.records, (item: OfflineSyncRecordLogSummary) => {
            this.RecordItem(item)
          }, (item: OfflineSyncRecordLogSummary) => `${item.clientBatchId}-${item.clientRecordId}`)
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
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(36)
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无同步处理记录')
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
  RecordItem(item: OfflineSyncRecordLogSummary) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(OfflineSyncRecordLogService.getStatusTone(item.status))

        Column({ space: 4 }) {
          Text(OfflineSyncRecordLogService.formatRecordType(item.recordType))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.clientRecordId)
            .fontSize(12)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(OfflineSyncRecordLogService.formatStatus(item.status))
          .fontSize(13)
          .fontColor(OfflineSyncRecordLogService.getStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.CompactInfoRow('批次编号', item.clientBatchId, AppColors.TextSecondary)
      this.CompactInfoRow('操作人', item.operatorName.length > 0 ? item.operatorName : item.userId, AppColors.TextSecondary)
      this.CompactInfoRow('发起时间', OfflineSyncRecordLogService.formatTime(item.createdOfflineAt), AppColors.TextSecondary)
      this.CompactInfoRow('提交时间', OfflineSyncRecordLogService.formatTime(item.submittedAt), AppColors.TextSecondary)
      this.CompactInfoRow('处理时间', OfflineSyncRecordLogService.formatTime(item.processedAt === undefined ? '' : item.processedAt),
        AppColors.TextSecondary)
      if (item.serverRecordId !== undefined && item.serverRecordId.length > 0) {
        this.CompactInfoRow('后端记录', item.serverRecordId, AppColors.TextSecondary)
      }
      if (item.errorCode !== undefined && item.errorCode.length > 0) {
        this.CompactInfoRow('错误码', item.errorCode, AppColors.Danger)
      }
      if (item.errorMessage !== undefined && item.errorMessage.length > 0) {
        Text(item.errorMessage)
          .fontSize(13)
          .fontColor(AppColors.Danger)
          .lineHeight(19)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  CompactInfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .width(72)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value.length === 0 ? '-' : value)
        .fontSize(13)
        .fontColor(tone)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
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
    const response = await OfflineSyncRecordLogService.queryRecentRecordsRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '同步处理记录刷新失败';
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    this.allRecords = data ? data.items : [];
    this.totalRecords = data ? data.total : this.allRecords.length;
    this.applyRecordFilters();
    this.message = '';
    this.refreshStatus = '已刷新';
  }

  applyRecordFilterResults(filterResults: FilterResult[]): void {
    filterResults.forEach((item: FilterResult) => {
      if (item.name === '同步状态') {
        this.statusFilterIndex = this.normalizeFilterIndex(item.index, SYNC_RECORD_STATUS_FILTER_VALUES.length);
      } else if (item.name === '业务类型') {
        this.typeFilterIndex = this.normalizeFilterIndex(item.index, SYNC_RECORD_TYPE_FILTER_VALUES.length);
      }
    });
    this.applyRecordFilters();
  }

  applyRecordFilters(): void {
    const statusValue = SYNC_RECORD_STATUS_FILTER_VALUES[this.statusFilterIndex];
    const typeValue = SYNC_RECORD_TYPE_FILTER_VALUES[this.typeFilterIndex];
    this.records = this.allRecords.filter((item: OfflineSyncRecordLogSummary) => {
      const matchesStatus = statusValue.length === 0 || item.status === statusValue;
      const matchesType = typeValue.length === 0 || item.recordType === typeValue;
      return matchesStatus && matchesType;
    });
  }

  getRecordFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('同步状态', SYNC_RECORD_STATUS_FILTER_OPTIONS),
      this.createFilterParams('业务类型', SYNC_RECORD_TYPE_FILTER_OPTIONS)
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

  getRecordCountText(): string {
    if (this.totalRecords > this.records.length) {
      return `${this.records.length}/${this.totalRecords}条`;
    }

    return `${this.records.length}条`;
  }

  backToManagementCenter(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ManagementCenter/ManagementCenter' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
