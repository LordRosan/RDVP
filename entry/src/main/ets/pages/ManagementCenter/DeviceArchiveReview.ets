import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import {
  DeviceArchiveChangeFieldDiff,
  DeviceArchiveReviewDecision,
  DeviceArchiveReviewItem,
  DeviceArchiveReviewRequestType
} from '../../models/DeviceArchiveReviewModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceArchiveReviewService } from '../../services/DeviceArchiveReviewService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const REVIEW_TYPE_FILTER_OPTIONS: string[] = ['全部类型', '添加档案', '删除档案', '修改档案'];
const REVIEW_TYPE_FILTER_VALUES: string[] = ['', 'CREATE', 'DELETE', 'UPDATE'];

@Entry
@Component
struct DeviceArchiveReview {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State allRequests: DeviceArchiveReviewItem[] = [];
  @State requests: DeviceArchiveReviewItem[] = [];
  @State requestTypeFilterIndex: number = 0;
  @State selectedRequestId: string = '';
  @State reviewDecision: string = '';
  @State reviewedAt: string = '';
  @State reviewComment: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State refreshMessage: string = '';
  @State refreshMessageTone: string = AppColors.Danger;
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.MgmtArchiveChangeReview)) {
      return;
    }

    this.refreshRequests();
  }

  onPageShow(): void {
    if (SessionStore.isAuthenticated() && this.canReview()) {
      this.refreshRequests();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.RequestListPanel()
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
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToWorkbench();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
      Text('档案审核')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
    .alignSelf(ItemAlign.Start)
    .padding({ top: 0, bottom: 2 })
  }

  @Builder
  RequestListPanel() {
    Column({ space: 10 }) {
      this.RefreshMessageText()

      Row() {
        Text('审核申请列表')
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
        .backgroundColor(this.refreshing || this.submitting ? AppColors.Disabled : AppColors.Primary)
        .enabled(!this.refreshing && !this.submitting)
        .onClick(() => {
          this.refreshRequests();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Filter({
        multiFilters: this.getRequestFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyRequestFilterResults(filterResults);
        },
        filterType: FilterType.LIST_FILTER
      }) {
        this.RequestFilterResultList()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RequestFilterResultList() {
    Column({ space: 12 }) {
      if (this.requests.length === 0) {
        this.EmptyState()
      } else {
        ForEach(this.requests, (item: DeviceArchiveReviewItem) => {
          this.RequestItem(item)
        }, (item: DeviceArchiveReviewItem) => item.id)
      }
      this.ReviewForm()
      this.StatusPanel()
    }
    .width('100%')
  }

  @Builder
  RequestItem(item: DeviceArchiveReviewItem) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph(this.getRequestTypeIcon(item.type))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(DeviceArchiveReviewService.getRequestTypeTone(item.type))

        Column({ space: 4 }) {
          Text(DeviceArchiveReviewService.formatRequestType(item.type))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.deviceCode)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(DeviceArchiveReviewService.formatStatus(item.status))
          .fontSize(13)
          .fontColor(DeviceArchiveReviewService.getStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.RequestTimeRow('设备标准编号', item.deviceCode)
      this.RequestTimeRow('标准审核编号', item.id)
      this.RequestTimeRow('申请人', this.getApplicantName(item))
      this.RequestTimeRow('提交时间', this.formatReviewTime(item.submittedAt))

      Row() {
        Text(item.reason)
          .fontSize(14)
          .fontColor(AppColors.TextSecondary)
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Column({ space: 8 }) {
        ForEach(item.changes, (change: DeviceArchiveChangeFieldDiff) => {
          this.ChangeDiffRow(change)
        }, (change: DeviceArchiveChangeFieldDiff) => `${item.id}-${change.field}`)
      }
      .width('100%')

      this.SelectRequestButton(item)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .border({
      width: this.selectedRequestId === item.id ? 2 : 0,
      color: this.selectedRequestId === item.id ? AppColors.Primary : AppColors.Transparent
    })
  }

  @Builder
  RequestTimeRow(label: string, value: string) {
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
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  ChangeDiffRow(change: DeviceArchiveChangeFieldDiff) {
    Column({ space: 4 }) {
      Text(change.label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text(`${change.oldValue} -> ${change.newValue}`)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .lineHeight(19)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: 10,
      bottom: 10
    })
    .backgroundColor(AppColors.FieldBackground)
    .borderRadius(14)
  }

  @Builder
  SelectRequestButton(item: DeviceArchiveReviewItem) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(
          this.selectedRequestId === item.id ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.text_clipboard'))
          .fontSize(18)
          .fontColor([AppColors.OnPrimary])

        Text(this.selectedRequestId === item.id ? '已选择' : '选择审核')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(46)
    .width('100%')
    .backgroundColor(this.selectedRequestId === item.id ? AppColors.Success : AppColors.Primary)
    .enabled(!this.submitting)
    .onClick(() => {
      this.selectRequest(item);
    })
  }

  @Builder
  ReviewForm() {
    Column({ space: 16 }) {
      this.FieldTitle('审核结果')
      this.RequestIdField()
      this.DecisionSelector()
      this.ReviewedAtField()
      if (this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}`) {
        this.ReviewCommentField()
      }
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), $r('sys.symbol.checkmark_circle'), this.canSubmitReview(), () => {
        this.submitReview();
      })
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RequestIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('标准审核编号')

      TextInput({
        placeholder: '请先选择待审核申请',
        text: this.selectedRequestId
      })
        .height(56)
        .fontSize(16)
        .fontColor(this.selectedRequestId.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DecisionSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('审核结论')

      Row({ space: 10 }) {
        this.DecisionOption(DeviceArchiveReviewDecision.Approved, $r('sys.symbol.checkmark_circle'))
        this.DecisionOption(DeviceArchiveReviewDecision.Rejected, $r('sys.symbol.xmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DecisionOption(decision: DeviceArchiveReviewDecision, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.reviewDecision === `${decision}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(DeviceArchiveReviewService.formatDecision(decision))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.reviewDecision === `${decision}` ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(46)
    .layoutWeight(1)
    .backgroundColor(this.reviewDecision === `${decision}` ? this.getDecisionTone(decision) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.reviewDecision === `${decision}` ? this.getDecisionTone(decision) : AppColors.Border
    })
    .enabled(!this.submitting)
    .onClick(() => {
      this.reviewDecision = `${decision}`;
      this.message = '';
      this.messageTone = AppColors.Danger;
    })
  }

  @Builder
  ReviewedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('审核时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.reviewedAt.length > 0 ? this.reviewedAt : '选择审核时间')
          .fontSize(16)
          .fontColor(this.reviewedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor([AppColors.TextSecondary])
      }
      .height(56)
      .width('100%')
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .border({ width: 1, color: AppColors.Border })
      .onClick(() => {
        if (this.submitting) {
          return;
        }

        this.showReviewedAtPicker();
        this.message = '';
        this.messageTone = AppColors.Danger;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReviewCommentField() {
    Column({ space: 10 }) {
      this.FieldTitle('审核意见')

      TextArea({
        placeholder: '填写驳回依据、需补充材料或建议修正内容',
        text: this.reviewComment
      })
        .height(104)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(500)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.submitting)
        .onChange((value: string) => {
          this.reviewComment = value;
          this.message = '';
          this.messageTone = AppColors.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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

      Text('暂无待审核申请')
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
  StatusPanel() {
    Column({ space: 10 }) {
      Text('审核状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '待审核数量', value: `${this.requests.length}项`, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '当前申请',
          value: this.selectedRequestId.length > 0 ? this.selectedRequestId : '-',
          tone: this.selectedRequestId.length > 0 ? AppColors.Primary : AppColors.TextSecondary
        })
        this.CardDivider()
        StatusInfoRow({
          label: '刷新状态',
          value: this.isFailureMessageVisible() ? '处理失败' : this.refreshStatus,
          tone: this.isFailureMessageVisible() ? AppColors.Danger : AppColors.Success
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
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  RefreshMessageText() {
    if (this.refreshMessage.length > 0) {
      Text(this.refreshMessage)
        .fontSize(13)
        .fontColor(this.refreshMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(enabled ? AppColors.Primary : AppColors.Disabled)
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
      .margin({ left: 18, right: 18 })
  }

  async refreshRequests(clearMessage: boolean = true): Promise<void> {
    if (this.refreshing || this.submitting) {
      return;
    }

    if (!this.canReview()) {
      this.refreshMessage = '当前账号无权审核设备档案变更';
      this.refreshMessageTone = AppColors.Danger;
      return;
    }

    this.refreshing = true;
    const response = await DeviceArchiveReviewService.listPendingReviewsRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.refreshMessage = error ? error.message : '变更申请刷新失败';
      this.refreshMessageTone = AppColors.Danger;
      this.refreshStatus = '刷新失败';
      return;
    }

    this.allRequests = response.data === undefined ? [] : response.data.items;
    this.applyRequestFilters();
    if (this.selectedRequestId.length > 0 && !this.hasRequest(this.selectedRequestId)) {
      this.clearReviewForm();
    }

    this.refreshMessage = '';
    this.refreshMessageTone = AppColors.Danger;
    if (clearMessage) {
      this.message = '';
      this.messageTone = AppColors.Danger;
    }
    this.refreshStatus = '已刷新';
  }

  selectRequest(item: DeviceArchiveReviewItem): void {
    this.selectedRequestId = item.id;
    this.reviewDecision = '';
    this.reviewComment = '';
    this.reviewedAt = '';
    this.message = '';
    this.messageTone = AppColors.Danger;
  }

  applyRequestFilters(): void {
    const typeValue = REVIEW_TYPE_FILTER_VALUES[this.requestTypeFilterIndex];
    this.requests = this.allRequests.filter((item: DeviceArchiveReviewItem) => {
      return typeValue.length === 0 || item.type === typeValue;
    });
  }

  applyRequestFilterResults(filterResults: FilterResult[]): void {
    const result = filterResults.find((item: FilterResult) => {
      return item.name === '申请类型';
    });
    this.requestTypeFilterIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, REVIEW_TYPE_FILTER_VALUES.length);
    this.applyRequestFilters();
  }

  getRequestFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('申请类型', REVIEW_TYPE_FILTER_OPTIONS)
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

  async submitReview(): Promise<void> {
    if (!this.canSubmitReview()) {
      this.fillSubmitValidationMessage();
      return;
    }

    this.submitting = true;
    const decision = this.reviewDecision as DeviceArchiveReviewDecision;
    const response = await DeviceArchiveReviewService.reviewChangeRequestRemoteFirst({
      requestId: this.selectedRequestId,
      decision,
      reviewedAt: this.reviewedAt,
      reviewComment: this.reviewComment
    });
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '档案审核失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.message = `${DeviceArchiveReviewService.formatDecision(decision)}完成`;
    this.messageTone = AppColors.Success;
    this.refreshStatus = '已更新';
    this.clearReviewForm();
    await this.refreshRequests(false);
  }

  canSubmitReview(): boolean {
    return this.canReview() && !this.refreshing && !this.submitting &&
      this.selectedRequestId.length > 0 &&
      this.hasReviewDecision() &&
      this.reviewedAt.length > 0 &&
      (this.reviewDecision !== `${DeviceArchiveReviewDecision.Rejected}` || this.reviewComment.trim().length > 0);
  }

  fillSubmitValidationMessage(): void {
    if (this.selectedRequestId.length === 0) {
      this.message = '请先选择待审核申请';
    } else if (!this.hasReviewDecision()) {
      this.message = '请选择审核结论';
    } else if (this.reviewedAt.length === 0) {
      this.message = '请选择审核时间';
    } else if (this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}` &&
      this.reviewComment.trim().length === 0) {
      this.message = '驳回申请时必须填写审核意见';
    } else {
      this.message = '当前不可提交审核结果';
    }
    this.messageTone = AppColors.Danger;
  }

  clearReviewForm(): void {
    this.selectedRequestId = '';
    this.reviewDecision = '';
    this.reviewComment = '';
    this.reviewedAt = '';
  }

  canReview(): boolean {
    return SessionStore.hasPermission(PermissionCode.MgmtArchiveChangeReview);
  }

  hasRequest(requestId: string): boolean {
    return this.requests.some((item: DeviceArchiveReviewItem) => {
      return item.id === requestId;
    });
  }

  hasReviewDecision(): boolean {
    return this.reviewDecision === `${DeviceArchiveReviewDecision.Approved}` ||
      this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}`;
  }

  getApplicantName(item: DeviceArchiveReviewItem): string {
    return item.applicantName === undefined || item.applicantName.length === 0 ? '-' : item.applicantName;
  }

  isFailureMessageVisible(): boolean {
    return this.refreshMessage.length > 0 && this.refreshMessageTone === AppColors.Danger;
  }

  getSubmitButtonLabel(): string {
    return this.submitting ? '提交中' : '提交审核结果';
  }

  getDecisionTone(decision: DeviceArchiveReviewDecision): string {
    return decision === DeviceArchiveReviewDecision.Approved ? AppColors.Success : AppColors.Danger;
  }

  getRequestTypeIcon(type: DeviceArchiveReviewRequestType): Resource {
    switch (type) {
      case DeviceArchiveReviewRequestType.Create:
        return $r('sys.symbol.plus_circle');
      case DeviceArchiveReviewRequestType.Delete:
        return $r('sys.symbol.trash');
      case DeviceArchiveReviewRequestType.Update:
      default:
        return $r('sys.symbol.text_clipboard');
    }
  }

  formatReviewTime(value: string): string {
    const normalized = value.trim();
    if (normalized.length === 0) {
      return '-';
    }

    return normalized.replace('T', ' ').replace('Z', '');
  }

  showReviewedAtPicker(): void {
    if (this.submitting) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.reviewedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.reviewedAt = this.formatDateTime(value);
        this.message = '';
        this.messageTone = AppColors.Danger;
      }
    });
  }

  resolveSelectedDate(value: string): Date {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return new Date();
    }

    const segments = trimmed.split(' ');
    if (segments.length !== 2) {
      return new Date();
    }

    const dateSegments = segments[0].split('-');
    const timeSegments = segments[1].split(':');
    if (dateSegments.length !== 3 || timeSegments.length < 2) {
      return new Date();
    }

    const year = Number(dateSegments[0]);
    const month = Number(dateSegments[1]);
    const day = Number(dateSegments[2]);
    const hour = Number(timeSegments[0]);
    const minute = Number(timeSegments[1]);
    if (year !== year || month !== month || day !== day || hour !== hour || minute !== minute) {
      return new Date();
    }

    return new Date(year, month - 1, day, hour, minute);
  }

  formatDateTime(value: Date): string {
    return `${value.getFullYear()}-${this.pad2(value.getMonth() + 1)}-${this.pad2(value.getDate())} ${this.pad2(
      value.getHours())}:${this.pad2(value.getMinutes())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
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
