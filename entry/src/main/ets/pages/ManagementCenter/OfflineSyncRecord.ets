import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OfflineSyncRecordLogSummary } from '../../models/OfflineSyncRecordLogModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { OfflineSyncRecordLogService } from '../../services/OfflineSyncRecordLogService';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct OfflineSyncRecord {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State records: OfflineSyncRecordLogSummary[] = [];
  @State totalRecords: number = 0;
  @State message: string = '';
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;

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
    this.records = data ? data.items : [];
    this.totalRecords = data ? data.total : this.records.length;
    this.message = '';
    this.refreshStatus = '已刷新';
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
