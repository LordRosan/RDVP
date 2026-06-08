import { Filter, FilterType } from '@kit.ArkUI';
import type { FilterParams, FilterResult } from '@kit.ArkUI';
import { AppColors } from '../../styles/AppTheme';
import {
  OfflineSyncExecutionItemResult,
  OfflineSyncItem,
  OfflineSyncItemStatus,
  OfflineSyncOperationType,
  OfflineSyncSettings,
  OfflineSyncSummary
} from '../../models/OfflineSyncModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { AuthService } from '../../services/AuthService';
import { OfflineSyncProcessorService } from '../../services/OfflineSyncProcessorService';
import { OfflineSyncService } from '../../services/OfflineSyncService';
import { WorkbenchService } from '../../services/WorkbenchService';
import { SessionStore } from '../../stores/SessionStore';

const MANUAL_SYNC_BATCH_LIMIT = 5;
const AUTO_SYNC_LIMIT_MIN = 1;
const AUTO_SYNC_LIMIT_MAX = 5;
const QUEUE_STATUS_FILTER_OPTIONS: string[] = ['全部状态', '待同步', '同步中', '已同步', '同步失败'];
const QUEUE_STATUS_FILTER_VALUES: string[] = ['ALL', 'PENDING', 'SYNCING', 'SYNCED', 'FAILED'];
const QUEUE_OPERATION_FILTER_OPTIONS: string[] = ['全部类型', '设备核验与报修', '设备核验', '故障报告', '档案新增申请', '档案变更申请', '档案删除申请'];
const QUEUE_OPERATION_FILTER_VALUES: string[] = [
  'ALL',
  'DEVICE_VERIFICATION_FAULT_REPORT_CREATE',
  'DEVICE_VERIFICATION_CREATE',
  'FAULT_REPORT_CREATE',
  'DEVICE_ARCHIVE_CREATE_REQUEST_CREATE',
  'DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE',
  'DEVICE_ARCHIVE_DELETE_REQUEST_CREATE'
];
const RESULT_STATUS_FILTER_OPTIONS: string[] = ['全部结果', '同步成功', '同步异常'];
const RESULT_STATUS_FILTER_VALUES: string[] = ['ALL', 'SUCCESS', 'FAILED'];

@Entry
@Component
struct SyncCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State summary: OfflineSyncSummary = OfflineSyncService.getSummary();
  @State settings: OfflineSyncSettings = OfflineSyncService.getSettings();
  @State items: OfflineSyncItem[] = OfflineSyncService.getItems();
  @State message: string = '';
  @State messageTone: string = AppColors.Primary;
  @State syncing: boolean = false;
  @State manualSyncConfirmVisible: boolean = false;
  @State manualSyncPreviewItems: OfflineSyncItem[] = [];
  @State manualSyncConfirmMessage: string = '';
  @State manualSyncConfirmMessageTone: string = AppColors.Warning;
  @State manualSyncPassword: string = '';
  @State manualSyncConfirmSubmitting: boolean = false;
  @State queueStatusFilterIndex: number = 0;
  @State queueOperationFilterIndex: number = 0;
  @State queueActionMessage: string = '';
  @State queueActionMessageTone: string = AppColors.Primary;
  @State queueActionMessageItemId: string = '';
  @State queueKeyword: string = '';
  @State lastSyncItemResults: OfflineSyncExecutionItemResult[] = [];
  @State resultStatusFilterIndex: number = 0;
  @State resultOperationFilterIndex: number = 0;
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.refreshState();
  }

  onPageShow(): void {
    if (SessionStore.isAuthenticated()) {
      this.refreshState();
    }
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          this.PageTitleBar()

          Column({ space: 18 }) {
            this.ModeHeader()
            this.OverviewPanel()
            this.PolicyPanel()
            if (this.lastSyncItemResults.length > 0) {
              this.LastSyncResultPanel()
            }
            this.QueuePanel()
          }
          .alignItems(HorizontalAlign.Start)
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
      }
      .height('100%')
      .width('100%')

      if (this.manualSyncConfirmVisible) {
        this.ManualSyncConfirmOverlay()
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    if (this.manualSyncConfirmVisible) {
      this.closeManualSyncConfirm();
      return true;
    }

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
      Text('同步中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('管理离线内容、同步策略、撤回和失败归档')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 2 })
  }

  @Builder
  OverviewPanel() {
    Column({ space: 10 }) {
      Text('队列概览')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        this.InfoRow('同步状态', OfflineSyncService.getStatusLabel(), OfflineSyncService.getStatusTone())
        this.CardDivider()
        this.InfoRow('待同步', `${this.summary.pendingCount}项`, this.summary.pendingCount > 0 ? AppColors.Warning : AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('可同步', `${this.summary.readyToSyncCount}项`, this.summary.readyToSyncCount > 0 ? AppColors.Primary : AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('同步失败', `${this.summary.failedCount}项`, this.summary.failedCount > 0 ? AppColors.Danger : AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('待人工处理', `${this.getManualHandlingCount()}项`,
          this.getManualHandlingCount() > 0 ? AppColors.Warning : AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('服务模式', ApiClient.getRuntimeStatusLabel(), ApiClient.getRuntimeStatusTone())
        this.CardDivider()
        this.InfoRow('自动同步', this.getAutoSyncPolicyText(),
          this.settings.autoSyncEnabled ? AppColors.Warning : AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('最近自动同步', OfflineSyncService.getLatestAutoSyncLabel(),
          OfflineSyncService.getLatestAutoSyncTone())
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)

      this.AutoSyncMessageText()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  PolicyPanel() {
    Column({ space: 10 }) {
      Text('同步策略')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column({ space: 12 }) {
        this.MessageText()

        Row({ space: 8 }) {
          this.PolicyButton(false, '手动同步', $r('sys.symbol.text_clipboard'))
          this.PolicyButton(true, '自动同步', $r('sys.symbol.arrow_clockwise'))
        }
        .width('100%')

        if (this.settings.autoSyncEnabled) {
          Text('恢复在线模式后将按批次自动同步；档案删除申请需手动验证密码后同步。')
            .fontSize(13)
            .fontColor(AppColors.Warning)
            .lineHeight(18)
            .width('100%')
        } else {
          Text('待同步内容保留在本地，可在同步前撤回。')
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .lineHeight(18)
            .width('100%')
        }

        if (this.settings.autoSyncEnabled) {
          Column({ space: 10 }) {
            Text('最大自动同步数量（1-5项）')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextPrimary)
              .width('100%')

            this.AutoSyncLimitPicker()
          }
          .width('100%')
        }

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(17)
              .fontColor([this.canManualSync() ? AppColors.OnPrimary : AppColors.TextSecondary])

            Text(this.syncing ? '同步中' : '同步本批次')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.canManualSync() ? AppColors.OnPrimary : AppColors.TextSecondary)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .height(46)
        .width('100%')
        .backgroundColor(this.canManualSync() ? AppColors.Primary : AppColors.FieldBackground)
        .enabled(this.canManualSync())
        .onClick(() => {
          this.openManualSyncConfirm();
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
  QueuePanel() {
    Column({ space: 10 }) {
      Text('同步内容')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      this.QueuePanelMessageText()
      this.QueueFilterPanel()

      if (this.items.length === 0) {
        Column({ space: 8 }) {
          Text('暂无同步内容')
            .fontSize(15)
            .fontColor(AppColors.TextSecondary)
        }
        .height(92)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppColors.Surface)
        .borderRadius(24)
      } else {
        if (this.getFilteredItems().length === 0) {
          this.FilterEmptyState()
        } else {
        Column({ space: 10 }) {
          ForEach(this.getFilteredItems(), (item: OfflineSyncItem) => {
            this.QueueItem(item)
          }, (item: OfflineSyncItem) => `${item.id}-${item.status}-${item.updatedAt}`)
        }
        .width('100%')
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  QueueItem(item: OfflineSyncItem) {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.getOperationLabel(item.operationType))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.payloadSummary)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.getItemStatusLabel(item))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getItemStatusTone(item))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column() {
        this.CompactInfoRow('发起时间', this.formatTime(item.createdAt), AppColors.TextSecondary)
        this.CompactInfoRow('更新时间', this.formatTime(item.updatedAt), AppColors.TextSecondary)
        this.CompactInfoRow('操作人', item.operatorName.length > 0 ? item.operatorName : '-', AppColors.TextSecondary)
        this.QueueStatusNote(item)
        if (this.hasRetrySchedule(item)) {
          this.CompactInfoRow('下次重试', this.formatTime(item.nextRetryAt ? item.nextRetryAt : ''), AppColors.Primary)
        }
        if (item.lastError !== undefined && item.lastError.length > 0) {
          this.CompactInfoRow('处理类型', this.getHandlingCategoryLabel(item), this.getHandlingCategoryTone(item))
          this.CompactInfoRow('处理建议', this.getHandlingSuggestion(item), this.getHandlingCategoryTone(item))
          if (item.lastErrorCode !== undefined && item.lastErrorCode.length > 0) {
            this.CompactInfoRow('错误码', item.lastErrorCode, AppColors.TextSecondary)
          }
          this.CompactInfoRow('失败原因', item.lastError, AppColors.Danger)
        }
      }
      .width('100%')

      this.QueueActionMessageText(item)
      this.QueueItemActions(item)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(16)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  @Builder
  InfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(15)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(54)
    .width('100%')
    .padding({
      left: 18,
      right: 18
    })
  }

  @Builder
  CompactInfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TextTertiary)
        .width(76)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(12)
        .fontColor(tone)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(28)
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QueueFilterPanel() {
    Column({ space: 10 }) {
      Row() {
        Text(this.getQueueFilterSummaryText())
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Text('重置')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
        }
        .height(34)
        .width(72)
        .backgroundColor(AppColors.FieldBackground)
        .border({ width: 1, color: AppColors.Border })
        .enabled(this.hasActiveQueueFilter())
        .onClick(() => {
          this.resetQueueFilters();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Filter({
        multiFilters: this.getQueueFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyQueueFilterResults(filterResults);
        },
        filterType: FilterType.MULTI_LINE_FILTER
      }) {
        Blank()
          .height(0)
      }

      TextInput({
        placeholder: '按设备编号、操作人、错误码或说明搜索',
        text: this.queueKeyword
      })
        .height(48)
        .fontSize(15)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .border({ width: 1, color: AppColors.Border })
        .onChange((value: string) => {
          this.queueKeyword = value;
          this.clearQueueActionMessage();
        })
    }
    .padding(14)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(16)
    .border({ width: 1, color: AppColors.Divider })
  }

  @Builder
  FilterEmptyState() {
    Column({ space: 8 }) {
      Text('当前筛选下暂无同步内容')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
    }
    .height(92)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  AutoSyncMessageText() {
    if (this.getLatestAutoSyncMessage().length > 0) {
      Text(`最近自动同步：${this.getLatestAutoSyncMessage()}`)
        .fontSize(13)
        .fontColor(OfflineSyncService.getLatestAutoSyncTone())
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  LastSyncResultPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('本次同步结果')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Row({ space: 8 }) {
          if (SessionStore.hasPermission(PermissionCode.MgmtAuditLogRead)) {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text('处理记录')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.OnPrimary)
                .maxLines(1)
            }
            .height(36)
            .width(92)
            .backgroundColor(AppColors.Primary)
            .onClick(() => {
              this.openSyncRecordPage();
            })
          }

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(17)
              .fontColor([AppColors.TextPrimary])
          }
          .width(38)
          .height(38)
          .backgroundColor(AppColors.Surface)
          .border({ width: 1, color: AppColors.Divider })
          .onClick(() => {
            this.lastSyncItemResults = [];
            this.resetResultFilters();
          })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.ResultFilterPanel()

      Column({ space: 10 }) {
        if (this.getFilteredLastSyncItemResults().length === 0) {
          this.ResultFilterEmptyState()
        } else {
          ForEach(this.getFilteredLastSyncItemResults(), (item: OfflineSyncExecutionItemResult) => {
            this.LastSyncResultItem(item)
          }, (item: OfflineSyncExecutionItemResult) => `${item.itemId}-${item.statusLabel}`)
        }
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  ResultFilterPanel() {
    Column({ space: 10 }) {
      Row() {
        Text(this.getResultFilterSummaryText())
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Text('重置')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
        }
        .height(34)
        .width(72)
        .backgroundColor(AppColors.FieldBackground)
        .border({ width: 1, color: AppColors.Border })
        .enabled(this.hasActiveResultFilter())
        .onClick(() => {
          this.resetResultFilters();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Filter({
        multiFilters: this.getResultFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyResultFilterResults(filterResults);
        },
        filterType: FilterType.MULTI_LINE_FILTER
      }) {
        Blank()
          .height(0)
      }
    }
    .padding(14)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(16)
    .border({ width: 1, color: AppColors.Divider })
  }

  @Builder
  ResultFilterEmptyState() {
    Column({ space: 8 }) {
      Text('当前筛选下暂无同步结果')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
    }
    .height(92)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  LastSyncResultItem(item: OfflineSyncExecutionItemResult) {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.getOperationLabel(item.operationType))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.payloadSummary)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(item.statusLabel)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.success ? AppColors.Success : AppColors.Danger)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

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
    .borderRadius(16)
    .border({
      width: 1,
      color: item.success ? AppColors.Divider : AppColors.Danger
    })
  }

  @Builder
  PolicyButton(autoSync: boolean, label: string, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(16)
          .fontColor([this.isPolicySelected(autoSync) ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isPolicySelected(autoSync) ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.isPolicySelected(autoSync) ? AppColors.Primary : AppColors.Surface)
    .border({
      width: 1,
      color: this.isPolicySelected(autoSync) ? AppColors.Primary : AppColors.Border
    })
    .onClick(() => {
      this.selectAutoSync(autoSync);
    })
  }

  @Builder
  AutoSyncLimitPicker() {
    Column({ space: 12 }) {
      Row() {
        Text('自动同步上限')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Text(`${this.settings.autoSyncBatchLimit}项`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.Primary)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Slider({
        value: this.settings.autoSyncBatchLimit,
        min: AUTO_SYNC_LIMIT_MIN,
        max: AUTO_SYNC_LIMIT_MAX,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .onChange((value: number) => {
          this.applyAutoSyncLimitValue(value);
        })

      Text('恢复在线后，自动同步按该上限分批提交；需密码验证的删除申请会保留待手动处理。')
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .lineHeight(18)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
  ManualSyncConfirmOverlay() {
    Column() {
      Column({ space: 16 }) {
        Row() {
          Text('确认同步本批次')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .layoutWeight(1)
            .maxLines(1)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18)
              .fontColor([AppColors.TextPrimary])
          }
          .width(40)
          .height(40)
          .backgroundColor(AppColors.PageBackground)
          .enabled(!this.isManualSyncBusy())
          .onClick(() => {
            this.closeManualSyncConfirm();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column() {
          this.SyncConfirmInfoRow('本批数量', `${this.manualSyncPreviewItems.length}项`, AppColors.Primary)
          this.CardDivider()
          this.SyncConfirmInfoRow('敏感操作', `${this.getManualSyncSensitiveCount()}项`,
            this.getManualSyncSensitiveCount() > 0 ? AppColors.Warning : AppColors.TextSecondary)
          this.CardDivider()
          this.SyncConfirmInfoRow('提交方式', '在线提交至后端处理', AppColors.TextSecondary)
        }
        .width('100%')
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)

        Text(this.getManualSyncConfirmHint())
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .lineHeight(19)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.getManualSyncPasswordRequiredCount() > 0) {
          this.ManualSyncPasswordField()
        }

        Row({ space: 10 }) {
          Column() {
            this.ConfirmSecondaryButton('取消', () => {
              this.closeManualSyncConfirm();
            })
          }
          .layoutWeight(1)

          Column({ space: 8 }) {
            this.ManualSyncConfirmMessageText()
            this.ConfirmPrimaryButton(this.isManualSyncBusy() ? '同步中' : '确认同步', () => {
              this.confirmManualSync();
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('88%')
      .padding({
        left: 22,
        right: 22,
        top: 22,
        bottom: 22
      })
      .backgroundColor(AppColors.Surface)
      .borderRadius(28)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Scrim)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ManualSyncPasswordField() {
    Column({ space: 8 }) {
      Text(`本批包含${this.getManualSyncPasswordRequiredCount()}项档案删除申请，需验证当前账号密码`)
        .fontSize(13)
        .fontColor(AppColors.Warning)
        .lineHeight(18)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      TextInput({
        placeholder: '请输入当前账号密码',
        text: this.manualSyncPassword
      })
        .type(InputType.Password)
        .height(48)
        .fontSize(15)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .border({ width: 1, color: AppColors.Border })
        .onChange((value: string) => {
          this.manualSyncPassword = value;
          if (this.manualSyncConfirmMessageTone === AppColors.Danger) {
            this.manualSyncConfirmMessage = '';
          }
        })
    }
    .width('100%')
  }

  @Builder
  ManualSyncConfirmMessageText() {
    if (this.manualSyncConfirmMessage.length > 0) {
      Text(this.manualSyncConfirmMessage)
        .fontSize(13)
        .fontColor(this.manualSyncConfirmMessageTone)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ConfirmPrimaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.isManualSyncBusy() }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.OnPrimary)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(this.isManualSyncBusy() ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.isManualSyncBusy())
    .onClick(() => {
      action();
    })
  }

  @Builder
  ConfirmSecondaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.isManualSyncBusy() }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(AppColors.FieldBackground)
    .border({ width: 1, color: AppColors.Border })
    .enabled(!this.isManualSyncBusy())
    .onClick(() => {
      action();
    })
  }

  @Builder
  SyncConfirmInfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(14)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(46)
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  QueueStatusNote(item: OfflineSyncItem) {
    Text(this.getBusinessStatusText(item))
      .fontSize(12)
      .fontColor(this.getBusinessStatusTone(item))
      .lineHeight(18)
      .maxLines(3)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .padding({ top: 4, bottom: 4 })
  }

  @Builder
  QueueActionMessageText(item: OfflineSyncItem) {
    if (this.queueActionMessageItemId === item.id && this.queueActionMessage.length > 0) {
      Text(this.queueActionMessage)
        .fontSize(13)
        .fontColor(this.queueActionMessageTone)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QueuePanelMessageText() {
    if (this.queueActionMessageItemId.length === 0 && this.queueActionMessage.length > 0) {
      Text(this.queueActionMessage)
        .fontSize(13)
        .fontColor(this.queueActionMessageTone)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QueueItemActions(item: OfflineSyncItem) {
    if (this.canRetryFailedItem(item)) {
      Row({ space: 10 }) {
        this.QueueItemActionButton('重试', AppColors.Primary, true, () => {
          this.retryFailedItem(item.id);
        })
        this.QueueItemActionButton('归档', AppColors.FieldBackground, true, () => {
          this.archiveFailedItem(item.id);
        }, AppColors.TextPrimary, AppColors.Border)
      }
      .width('100%')
    } else {
      this.QueueItemActionButton(
        this.getItemActionLabel(item),
        this.canOperateItem(item) ? this.getItemActionTone(item) : AppColors.FieldBackground,
        this.canOperateItem(item),
        () => {
          this.handleItemAction(item);
        },
        this.canOperateItem(item) ? AppColors.OnPrimary : AppColors.TextSecondary)
    }
  }

  @Builder
  QueueItemActionButton(
    label: string,
    backgroundColor: string,
    enabled: boolean,
    action: () => void,
    fontColor: string = AppColors.OnPrimary,
    borderColor: string = ''
  ) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(fontColor)
        .maxLines(1)
    }
    .height(40)
    .layoutWeight(1)
    .backgroundColor(backgroundColor)
    .border({
      width: borderColor.length > 0 ? 1 : 0,
      color: borderColor.length > 0 ? borderColor : backgroundColor
    })
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

  refreshState(): void {
    this.summary = OfflineSyncService.getSummary();
    this.settings = OfflineSyncService.getSettings();
    this.items = OfflineSyncService.getItems();
  }

  openManualSyncConfirm(): void {
    if (!this.canManualSync()) {
      return;
    }

    const readyItems = OfflineSyncService.getReadyPendingItems(MANUAL_SYNC_BATCH_LIMIT);
    if (readyItems.length === 0) {
      this.message = '暂无可同步项目';
      this.messageTone = AppColors.Warning;
      this.refreshState();
      return;
    }

    this.manualSyncPreviewItems = readyItems;
    this.manualSyncPassword = '';
    this.manualSyncConfirmMessage = this.getManualSyncPasswordRequiredCount() > 0 ?
      '本批包含档案删除申请，需验证当前账号密码后同步。' :
      (this.getManualSyncSensitiveCount() > 0 ? '本批包含档案类敏感操作，提交后将进入后端审核或冲突检测。' : '');
    this.manualSyncConfirmMessageTone = AppColors.Warning;
    this.manualSyncConfirmVisible = true;
  }

  closeManualSyncConfirm(): void {
    if (this.isManualSyncBusy()) {
      return;
    }

    this.manualSyncConfirmVisible = false;
    this.manualSyncPreviewItems = [];
    this.manualSyncConfirmMessage = '';
    this.manualSyncPassword = '';
  }

  async confirmManualSync(): Promise<void> {
    if (this.isManualSyncBusy()) {
      return;
    }

    if (!this.canManualSync()) {
      this.manualSyncConfirmMessage = '当前无可提交内容或未连接后端服务';
      this.manualSyncConfirmMessageTone = AppColors.Danger;
      this.refreshState();
      return;
    }

    this.manualSyncConfirmSubmitting = true;
    try {
      if (this.getManualSyncPasswordRequiredCount() > 0) {
        if (this.manualSyncPassword.length === 0) {
          this.manualSyncConfirmMessage = '请输入当前账号密码后再同步档案删除申请';
          this.manualSyncConfirmMessageTone = AppColors.Danger;
          return;
        }

        const verification = await AuthService.verifyCurrentUserPasswordRemoteFirst(this.manualSyncPassword);
        if (!verification.success || verification.data !== true) {
          this.manualSyncConfirmMessage = verification.error === undefined ?
            '密码验证失败，请重新输入' : verification.error.message;
          this.manualSyncConfirmMessageTone = AppColors.Danger;
          return;
        }
      }

      this.manualSyncConfirmVisible = false;
      this.manualSyncPreviewItems = [];
      this.manualSyncConfirmMessage = '';
      this.manualSyncPassword = '';
      await this.submitManualSync();
    } finally {
      this.manualSyncConfirmSubmitting = false;
    }
  }

  selectAutoSync(enabled: boolean): void {
    this.settings = OfflineSyncService.setAutoSyncSettings(enabled, this.settings.autoSyncBatchLimit);
    this.clearQueueActionMessage();
    this.message = enabled ?
      `已开启自动同步，恢复在线后将按每批最多${this.settings.autoSyncBatchLimit}项提交待同步内容。` :
      '已切换为手动同步，未同步内容可在同步前撤回。';
    this.messageTone = enabled ? AppColors.Warning : AppColors.Primary;
    this.refreshState();
  }

  updateAutoSyncLimit(limit: number): void {
    this.settings = OfflineSyncService.setAutoSyncSettings(true, limit);
    this.clearQueueActionMessage();
    this.message = `最大自动同步数量已设置为${this.settings.autoSyncBatchLimit}项`;
    this.messageTone = AppColors.Primary;
    this.refreshState();
  }

  async submitManualSync(): Promise<void> {
    if (!this.canManualSync()) {
      return;
    }

    this.syncing = true;
    this.message = '';
    try {
      const result = await OfflineSyncProcessorService.syncReadyItems(MANUAL_SYNC_BATCH_LIMIT);
      this.message = result.message;
      this.messageTone = result.failedCount > 0 ? AppColors.Danger : AppColors.Primary;
      this.resetResultFilters();
      this.lastSyncItemResults = result.itemResults;
    } catch (err) {
      this.message = '同步执行失败';
      this.messageTone = AppColors.Danger;
      this.resetResultFilters();
      this.lastSyncItemResults = [];
    } finally {
      try {
        await WorkbenchService.refreshSummaryRemoteFirst();
      } catch (refreshErr) {
      }
      this.syncing = false;
      this.refreshState();
    }
  }

  withdrawItem(id: string): void {
    if (this.settings.autoSyncEnabled) {
      this.setQueueActionMessage(id, '自动同步已开启，待同步内容不可手动撤回', AppColors.Danger);
      return;
    }

    if (!OfflineSyncService.withdrawPendingItem(id)) {
      this.setQueueActionMessage(id, '该内容当前不可撤回', AppColors.Danger);
      this.refreshState();
      return;
    }

    this.setQueueActionMessage('', '已撤回未同步内容', AppColors.Primary);
    this.refreshState();
  }

  archiveFailedItem(id: string): void {
    if (!OfflineSyncService.archiveFailedItem(id)) {
      this.setQueueActionMessage(id, '该失败记录当前不可归档', AppColors.Danger);
      this.refreshState();
      return;
    }

    this.setQueueActionMessage('', '已归档同步失败记录', AppColors.Primary);
    this.refreshState();
  }

  retryFailedItem(id: string): void {
    if (!OfflineSyncService.retryFailedItem(id)) {
      this.setQueueActionMessage(id, '该失败记录不可重试，请核对原因后重新发起或归档', AppColors.Danger);
      this.refreshState();
      return;
    }

    this.setQueueActionMessage(id, '已重新加入待同步队列，可在确认后提交本批次', AppColors.Primary);
    this.refreshState();
  }

  canManualSync(): boolean {
    return !this.settings.autoSyncEnabled && !this.syncing && this.summary.readyToSyncCount > 0 && ApiClient.isConfigured();
  }

  isManualSyncBusy(): boolean {
    return this.syncing || this.manualSyncConfirmSubmitting;
  }

  canWithdraw(item: OfflineSyncItem): boolean {
    return !this.settings.autoSyncEnabled && item.status === OfflineSyncItemStatus.Pending;
  }

  canArchiveFailedItem(item: OfflineSyncItem): boolean {
    return item.status === OfflineSyncItemStatus.Failed;
  }

  canRetryFailedItem(item: OfflineSyncItem): boolean {
    return item.status === OfflineSyncItemStatus.Failed && this.isRetryableError(item) && !this.syncing;
  }

  canOperateItem(item: OfflineSyncItem): boolean {
    return this.canWithdraw(item) || this.canArchiveFailedItem(item);
  }

  getItemActionLabel(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Failed) {
      return '归档';
    }

    return '撤回';
  }

  getItemActionTone(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Failed) {
      return AppColors.Primary;
    }

    return AppColors.Danger;
  }

  handleItemAction(item: OfflineSyncItem): void {
    if (item.status === OfflineSyncItemStatus.Failed) {
      this.archiveFailedItem(item.id);
      return;
    }

    this.withdrawItem(item.id);
  }

  applyQueueFilterResults(filterResults: FilterResult[]): void {
    if (filterResults.length === 0) {
      this.queueStatusFilterIndex = 0;
      this.queueOperationFilterIndex = 0;
      this.clearQueueActionMessage();
      return;
    }

    filterResults.forEach((item: FilterResult) => {
      if (item.name === '同步状态') {
        this.queueStatusFilterIndex = this.normalizePickerIndex(item.index, QUEUE_STATUS_FILTER_OPTIONS.length);
      } else if (item.name === '业务类型') {
        this.queueOperationFilterIndex = this.normalizePickerIndex(item.index, QUEUE_OPERATION_FILTER_OPTIONS.length);
      }
    });
    this.clearQueueActionMessage();
  }

  getQueueFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('同步状态', QUEUE_STATUS_FILTER_OPTIONS),
      this.createFilterParams('业务类型', QUEUE_OPERATION_FILTER_OPTIONS)
    ];
  }

  applyResultFilterResults(filterResults: FilterResult[]): void {
    if (filterResults.length === 0) {
      this.resultStatusFilterIndex = 0;
      this.resultOperationFilterIndex = 0;
      return;
    }

    filterResults.forEach((item: FilterResult) => {
      if (item.name === '结果状态') {
        this.resultStatusFilterIndex = this.normalizePickerIndex(item.index, RESULT_STATUS_FILTER_OPTIONS.length);
      } else if (item.name === '业务类型') {
        this.resultOperationFilterIndex = this.normalizePickerIndex(item.index, QUEUE_OPERATION_FILTER_OPTIONS.length);
      }
    });
  }

  getResultFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('结果状态', RESULT_STATUS_FILTER_OPTIONS),
      this.createFilterParams('业务类型', QUEUE_OPERATION_FILTER_OPTIONS)
    ];
  }

  createFilterParams(name: string, options: string[]): FilterParams {
    const params: FilterParams = {
      name: name,
      options: options
    };
    return params;
  }

  resetQueueFilters(): void {
    this.queueStatusFilterIndex = 0;
    this.queueOperationFilterIndex = 0;
    this.queueKeyword = '';
    this.clearQueueActionMessage();
  }

  resetResultFilters(): void {
    this.resultStatusFilterIndex = 0;
    this.resultOperationFilterIndex = 0;
  }

  hasActiveQueueFilter(): boolean {
    return this.queueStatusFilterIndex !== 0 || this.queueOperationFilterIndex !== 0 ||
      this.queueKeyword.trim().length > 0;
  }

  hasActiveResultFilter(): boolean {
    return this.resultStatusFilterIndex !== 0 || this.resultOperationFilterIndex !== 0;
  }

  getFilteredItems(): OfflineSyncItem[] {
    const filteredItems: OfflineSyncItem[] = [];
    this.items.forEach((item: OfflineSyncItem) => {
      if (this.matchesQueueStatusFilter(item) && this.matchesQueueOperationFilter(item) &&
        this.matchesQueueKeywordFilter(item)) {
        filteredItems.push(item);
      }
    });
    return filteredItems;
  }

  getFilteredLastSyncItemResults(): OfflineSyncExecutionItemResult[] {
    const filteredItems: OfflineSyncExecutionItemResult[] = [];
    this.lastSyncItemResults.forEach((item: OfflineSyncExecutionItemResult) => {
      if (this.matchesResultStatusFilter(item) && this.matchesResultOperationFilter(item)) {
        filteredItems.push(item);
      }
    });
    return filteredItems;
  }

  matchesQueueStatusFilter(item: OfflineSyncItem): boolean {
    const statusValue = QUEUE_STATUS_FILTER_VALUES[this.queueStatusFilterIndex];
    return statusValue === 'ALL' || item.status === statusValue;
  }

  matchesQueueOperationFilter(item: OfflineSyncItem): boolean {
    const operationValue = QUEUE_OPERATION_FILTER_VALUES[this.queueOperationFilterIndex];
    return operationValue === 'ALL' || item.operationType === operationValue;
  }

  matchesQueueKeywordFilter(item: OfflineSyncItem): boolean {
    const keyword = this.queueKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return true;
    }

    return item.id.toLowerCase().indexOf(keyword) >= 0 ||
      item.operationType.toLowerCase().indexOf(keyword) >= 0 ||
      this.getOperationLabel(item.operationType).toLowerCase().indexOf(keyword) >= 0 ||
      item.payloadSummary.toLowerCase().indexOf(keyword) >= 0 ||
      item.operatorName.toLowerCase().indexOf(keyword) >= 0 ||
      this.getOptionalText(item.lastErrorCode).toLowerCase().indexOf(keyword) >= 0 ||
      this.getOptionalText(item.lastError).toLowerCase().indexOf(keyword) >= 0 ||
      this.getOptionalText(item.conflictKey).toLowerCase().indexOf(keyword) >= 0 ||
      this.getOptionalText(item.serverVersion).toLowerCase().indexOf(keyword) >= 0;
  }

  matchesResultStatusFilter(item: OfflineSyncExecutionItemResult): boolean {
    const statusValue = RESULT_STATUS_FILTER_VALUES[this.resultStatusFilterIndex];
    return statusValue === 'ALL' ||
      (statusValue === 'SUCCESS' && item.success) ||
      (statusValue === 'FAILED' && !item.success);
  }

  matchesResultOperationFilter(item: OfflineSyncExecutionItemResult): boolean {
    const operationValue = QUEUE_OPERATION_FILTER_VALUES[this.resultOperationFilterIndex];
    return operationValue === 'ALL' || item.operationType === operationValue;
  }

  getQueueFilterSummaryText(): string {
    return `显示 ${this.getFilteredItems().length}/${this.items.length} 项`;
  }

  getResultFilterSummaryText(): string {
    return `显示 ${this.getFilteredLastSyncItemResults().length}/${this.lastSyncItemResults.length} 项`;
  }

  getAutoSyncPolicyText(): string {
    return this.settings.autoSyncEnabled ? `每批最多${this.settings.autoSyncBatchLimit}项` : '手动同步';
  }

  getLatestAutoSyncMessage(): string {
    if (this.summary.latestAutoSyncMessage === undefined) {
      return '';
    }

    return this.summary.latestAutoSyncMessage.trim();
  }

  normalizePickerIndex(index: number, length: number): number {
    if (index !== index || index < 0) {
      return 0;
    }

    if (index >= length) {
      return length - 1;
    }

    return Math.floor(index);
  }

  setQueueActionMessage(itemId: string, message: string, tone: string): void {
    this.message = '';
    this.queueActionMessageItemId = itemId;
    this.queueActionMessage = message;
    this.queueActionMessageTone = tone;
  }

  clearQueueActionMessage(): void {
    this.queueActionMessage = '';
    this.queueActionMessageItemId = '';
  }

  getOptionalText(value: string | undefined): string {
    return value === undefined ? '' : value;
  }

  isPolicySelected(autoSync: boolean): boolean {
    return this.settings.autoSyncEnabled === autoSync;
  }

  applyAutoSyncLimitValue(value: number): void {
    const normalizedValue = Math.max(AUTO_SYNC_LIMIT_MIN, Math.min(AUTO_SYNC_LIMIT_MAX, Math.round(value)));
    this.updateAutoSyncLimit(normalizedValue);
  }

  getManualSyncSensitiveCount(): number {
    let count = 0;
    this.manualSyncPreviewItems.forEach((item: OfflineSyncItem) => {
      if (this.isSensitiveSyncOperation(item.operationType)) {
        count += 1;
      }
    });
    return count;
  }

  getManualSyncPasswordRequiredCount(): number {
    let count = 0;
    this.manualSyncPreviewItems.forEach((item: OfflineSyncItem) => {
      if (OfflineSyncService.isPasswordVerificationRequiredOperation(item.operationType)) {
        count += 1;
      }
    });
    return count;
  }

  getManualSyncConfirmHint(): string {
    if (this.getManualSyncPasswordRequiredCount() > 0) {
      return '确认后本批内容会提交到后端。档案删除申请属于敏感操作，必须先完成当前账号密码验证；审核通过前不会直接删除设备档案。';
    }

    if (this.getManualSyncSensitiveCount() > 0) {
      return '确认后本批内容会提交到后端。档案新增、变更、删除不会直接生效，需通过审核；若后端检测到冻结、锁定、删除或版本冲突，将标记为冲突无效。';
    }

    return '确认后本批内容会提交到后端处理。提交成功后将进入对应业务流程，同步失败的内容会保留错误原因和处理建议。';
  }

  getOperationLabel(operationType: string): string {
    if (operationType === 'FAULT_REPORT_CREATE') {
      return '故障报告';
    }

    if (operationType === 'DEVICE_VERIFICATION_CREATE') {
      return '设备核验';
    }

    if (operationType === 'DEVICE_VERIFICATION_FAULT_REPORT_CREATE') {
      return '设备核验与报修';
    }

    if (operationType === 'DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE') {
      return '档案变更申请';
    }

    if (operationType === 'DEVICE_ARCHIVE_CREATE_REQUEST_CREATE') {
      return '档案新增申请';
    }

    if (operationType === 'DEVICE_ARCHIVE_DELETE_REQUEST_CREATE') {
      return '档案删除申请';
    }

    return '离线操作';
  }

  getItemStatusLabel(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Pending) {
      if (this.hasRetryError(item)) {
        return this.hasRetrySchedule(item) ? '等待重试' : '可重试';
      }

      return '已保存待同步';
    }

    if (item.status === OfflineSyncItemStatus.Syncing) {
      return '同步中';
    }

    if (item.status === OfflineSyncItemStatus.Synced) {
      return '已同步至后端';
    }

    return '同步失败';
  }

  getItemStatusTone(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Pending) {
      if (this.hasRetryError(item)) {
        return AppColors.Primary;
      }

      return AppColors.Warning;
    }

    if (item.status === OfflineSyncItemStatus.Syncing) {
      return AppColors.Primary;
    }

    if (item.status === OfflineSyncItemStatus.Synced) {
      return AppColors.Success;
    }

    return AppColors.Danger;
  }

  getBusinessStatusText(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Pending) {
      if (OfflineSyncService.isPasswordVerificationRequiredOperation(item.operationType)) {
        return '已保存至本地，档案删除申请需在同步中心手动验证密码并提交；同步成功并通过审核后才会生效。';
      }

      if (this.isArchiveSyncOperation(item.operationType)) {
        return '已保存至本地，尚未提交至后端；同步成功并通过审核后才会生效。';
      }

      return '已保存至本地，尚未提交至后端；恢复在线并同步后进入后续流程。';
    }

    if (item.status === OfflineSyncItemStatus.Syncing) {
      return '正在提交至后端，请勿重复提交或撤回。';
    }

    if (item.status === OfflineSyncItemStatus.Synced) {
      if (this.isArchiveSyncOperation(item.operationType)) {
        return '已同步至后端，等待审核或后端冲突处理结果。';
      }

      return '已同步至后端，已进入对应业务处理流程。';
    }

    if (this.isConflictError(item)) {
      return '后端已判定冲突，该内容未进入审核流程。';
    }

    return '同步失败，请按处理建议检查后重新发起或归档失败记录。';
  }

  getBusinessStatusTone(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Synced) {
      return AppColors.Success;
    }

    if (item.status === OfflineSyncItemStatus.Failed) {
      return AppColors.Danger;
    }

    return AppColors.TextSecondary;
  }

  getManualHandlingCount(): number {
    let count = 0;
    this.items.forEach((item: OfflineSyncItem) => {
      if (item.status === OfflineSyncItemStatus.Failed && !this.isRetryableError(item)) {
        count += 1;
      }
    });
    return count;
  }

  getHandlingCategoryLabel(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Pending && this.hasRetryError(item)) {
      return '可重试';
    }

    if (this.isConflictError(item)) {
      return '冲突无效';
    }

    if (this.isInvalidRecordError(item)) {
      return '内容无效';
    }

    if (this.isRetryableError(item)) {
      return item.status === OfflineSyncItemStatus.Failed ? '重试受限' : '可重试';
    }

    return '需人工处理';
  }

  getHandlingCategoryTone(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Pending && this.hasRetryError(item)) {
      return AppColors.Primary;
    }

    if (this.isConflictError(item)) {
      return AppColors.Danger;
    }

    if (this.isInvalidRecordError(item)) {
      return AppColors.Danger;
    }

    if (this.isRetryableError(item)) {
      return AppColors.Warning;
    }

    return AppColors.Warning;
  }

  getHandlingSuggestion(item: OfflineSyncItem): string {
    if (item.status === OfflineSyncItemStatus.Pending && this.hasRetryError(item)) {
      return '系统将按退避策略再次同步，也可稍后手动触发同步';
    }

    if (this.isConflictError(item)) {
      return '该内容未进入审核流程，请核对最新档案或业务状态后重新发起';
    }

    if (this.isInvalidRecordError(item)) {
      return '请校准设备时间或核对离线内容后重新提交；此类记录不会进入审核流程';
    }

    if (this.isRetryableError(item)) {
      return '请确认后端服务稳定后重新发起同步，必要时调整批次数量';
    }

    return '请检查权限、内容格式或业务前置条件后重新提交';
  }

  hasRetryError(item: OfflineSyncItem): boolean {
    return item.lastError !== undefined && item.lastError.trim().length > 0 &&
      item.status === OfflineSyncItemStatus.Pending;
  }

  hasRetrySchedule(item: OfflineSyncItem): boolean {
    return item.nextRetryAt !== undefined && item.nextRetryAt.trim().length > 0 &&
      item.status === OfflineSyncItemStatus.Pending;
  }

  isRetryableError(item: OfflineSyncItem): boolean {
    const errorCode = this.getErrorCode(item);
    return errorCode === 'INTERNAL_ERROR' ||
      errorCode === 'SERVICE_UNAVAILABLE' ||
      errorCode === 'RATE_LIMITED';
  }

  isConflictError(item: OfflineSyncItem): boolean {
    const errorCode = this.getErrorCode(item);
    return errorCode === 'CONFLICT' ||
      errorCode === 'OFFLINE_RECORD_CONFLICT' ||
      errorCode === 'DEVICE_CHANGE_LOCKED' ||
      errorCode === 'DEVICE_CHANGE_FROZEN' ||
      errorCode === 'DEVICE_CODE_DUPLICATED' ||
      errorCode === 'DEVICE_ARCHIVE_DELETE_BLOCKED' ||
      errorCode === 'DEVICE_ACTIVE_FAULT_EXISTS' ||
      errorCode === 'DEVICE_NOT_FOUND';
  }

  isInvalidRecordError(item: OfflineSyncItem): boolean {
    const errorCode = this.getErrorCode(item);
    return errorCode === 'OFFLINE_SYNC_RECORD_INVALID' ||
      errorCode === 'OFFLINE_SYNC_BATCH_INVALID' ||
      errorCode === 'VALIDATION_FAILED' ||
      errorCode === 'BAD_REQUEST';
  }

  getErrorCode(item: OfflineSyncItem): string {
    if (item.lastErrorCode !== undefined && item.lastErrorCode.trim().length > 0) {
      return item.lastErrorCode.trim();
    }

    if (item.lastError === undefined) {
      return '';
    }

    const errorText = item.lastError.trim();
    const chineseSeparatorIndex = errorText.indexOf('：');
    if (chineseSeparatorIndex > 0) {
      return errorText.substring(0, chineseSeparatorIndex).trim();
    }

    const separatorIndex = errorText.indexOf(':');
    if (separatorIndex > 0) {
      return errorText.substring(0, separatorIndex).trim();
    }

    return '';
  }

  isSensitiveSyncOperation(operationType: string): boolean {
    return this.isArchiveSyncOperation(operationType);
  }

  isArchiveSyncOperation(operationType: string): boolean {
    return operationType === OfflineSyncOperationType.DeviceArchiveUpdateRequestCreate ||
      operationType === OfflineSyncOperationType.DeviceArchiveCreateRequestCreate ||
      operationType === OfflineSyncOperationType.DeviceArchiveDeleteRequestCreate;
  }

  formatTime(value: string): string {
    if (value.length === 0) {
      return '-';
    }

    return value.replace('T', ' ').replace('Z', '');
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

  openSyncRecordPage(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ManagementCenter/OfflineSyncRecord' });
    } catch (err) {
      this.queueActionMessage = '同步处理记录不可用';
      this.queueActionMessageTone = AppColors.Danger;
      this.queueActionMessageItemId = '';
    }
  }

  openLoginPage(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Login' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
