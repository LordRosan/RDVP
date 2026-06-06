import { AppColors } from '../../styles/AppTheme';
import {
  OfflineSyncItem,
  OfflineSyncItemStatus,
  OfflineSyncSettings,
  OfflineSyncSummary
} from '../../models/OfflineSyncModels';
import { ApiClient } from '../../services/ApiClient';
import { OfflineSyncProcessorService } from '../../services/OfflineSyncProcessorService';
import { OfflineSyncService } from '../../services/OfflineSyncService';
import { WorkbenchService } from '../../services/WorkbenchService';
import { SessionStore } from '../../stores/SessionStore';

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
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.OverviewPanel()
          this.PolicyPanel()
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
      Text('同步中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('管理离线内容、同步策略和撤回操作')
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
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
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
          Text('恢复在线模式后将按批次自动同步，已进入同步流程的内容不可手动撤回。')
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
          Column({ space: 8 }) {
            Text('最大自动同步数量（1-5项）')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextPrimary)
              .width('100%')

            Row({ space: 8 }) {
              ForEach(this.createLimitOptions(), (limit: number) => {
                this.LimitButton(limit)
              }, (limit: number) => `${limit}`)
            }
            .width('100%')
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
          this.submitManualSync();
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
        Column({ space: 10 }) {
          ForEach(this.items, (item: OfflineSyncItem) => {
            this.QueueItem(item)
          }, (item: OfflineSyncItem) => `${item.id}-${item.status}-${item.updatedAt}`)
        }
        .width('100%')
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

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text('撤回')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canWithdraw(item) ? AppColors.OnPrimary : AppColors.TextSecondary)
      }
      .height(40)
      .width('100%')
      .backgroundColor(this.canWithdraw(item) ? AppColors.Danger : AppColors.FieldBackground)
      .enabled(this.canWithdraw(item))
      .onClick(() => {
        this.withdrawItem(item.id);
      })
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
  LimitButton(limit: number) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text(`${limit}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.settings.autoSyncBatchLimit === limit ? AppColors.OnPrimary : AppColors.TextPrimary)
    }
    .width(38)
    .height(38)
    .backgroundColor(this.settings.autoSyncBatchLimit === limit ? AppColors.Primary : AppColors.Surface)
    .border({
      width: 1,
      color: this.settings.autoSyncBatchLimit === limit ? AppColors.Primary : AppColors.Border
    })
    .onClick(() => {
      this.updateAutoSyncLimit(limit);
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

  selectAutoSync(enabled: boolean): void {
    this.settings = OfflineSyncService.setAutoSyncSettings(enabled, this.settings.autoSyncBatchLimit);
    this.message = enabled ?
      `已开启自动同步，恢复在线后将按每批最多${this.settings.autoSyncBatchLimit}项提交待同步内容。` :
      '已切换为手动同步，未同步内容可在同步前撤回。';
    this.messageTone = enabled ? AppColors.Warning : AppColors.Primary;
    this.refreshState();
  }

  updateAutoSyncLimit(limit: number): void {
    this.settings = OfflineSyncService.setAutoSyncSettings(true, limit);
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
      const result = await OfflineSyncProcessorService.syncReadyItems(5);
      this.message = result.message;
      this.messageTone = result.failedCount > 0 ? AppColors.Danger : AppColors.Primary;
    } catch (err) {
      this.message = '同步执行失败';
      this.messageTone = AppColors.Danger;
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
      this.message = '自动同步已开启，待同步内容不可手动撤回';
      this.messageTone = AppColors.Danger;
      return;
    }

    if (!OfflineSyncService.withdrawPendingItem(id)) {
      this.message = '该内容当前不可撤回';
      this.messageTone = AppColors.Danger;
      this.refreshState();
      return;
    }

    this.message = '已撤回未同步内容';
    this.messageTone = AppColors.Primary;
    this.refreshState();
  }

  canManualSync(): boolean {
    return !this.settings.autoSyncEnabled && !this.syncing && this.summary.readyToSyncCount > 0 && ApiClient.isConfigured();
  }

  canWithdraw(item: OfflineSyncItem): boolean {
    return !this.settings.autoSyncEnabled && item.status === OfflineSyncItemStatus.Pending;
  }

  isPolicySelected(autoSync: boolean): boolean {
    return this.settings.autoSyncEnabled === autoSync;
  }

  createLimitOptions(): number[] {
    return [1, 2, 3, 4, 5];
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
