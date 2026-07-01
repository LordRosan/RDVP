import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import {
  DeviceArchiveRequestFieldDiff,
  DeviceArchiveReviewDecision,
  DeviceArchiveReviewItem,
  DeviceArchiveReviewRequestType
} from '../../models/archive/DeviceArchiveReviewModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { DeviceArchiveReviewService } from '../../services/review/DeviceArchiveReviewService';
import { AuthService } from '../../services/identity/AuthService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { AppNavigator } from '../../utils/AppNavigator';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

const REVIEW_TYPE_FILTER_OPTIONS: string[] = ['全部', '添加档案', '删除档案', '修改档案'];
const REVIEW_TYPE_FILTER_VALUES: string[] = ['', 'CREATE', 'DELETE', 'UPDATE'];
const REVIEW_FILTER_CONTROL_HEIGHT = 56;

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
  @State password: string = '';
  @State message: string = '';
  @State messageTone: string = UiFeedbackTone.Danger;
  @State refreshMessage: string = '';
  @State refreshMessageTone: string = UiFeedbackTone.Danger;
  @State refreshing: boolean = false;
  @State submitting: boolean = false;
  @State reviewReady: boolean = false;
  @State filterResetRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ReviewCenterDeviceArchiveRequestReview)) {
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
          this.Header()
          this.RequestListPanel()
          this.ReviewForm()
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
    this.backToReviewCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToReviewCenter();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text('档案审核')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Archive Review')
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
  RequestListPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '待审核操作列表',
        subtitle: ''
      })

      Column({ space: 14 }) {
        this.RequestTypeFilterControl()

        this.RefreshMessageText()
        this.ListActionButtons()
        this.RequestFilterResultList()
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
  RequestTypeFilterControl() {
    if (this.filterResetRevision % 2 === 0) {
      this.RequestTypeFilterInstance()
    } else {
      this.RequestTypeFilterInstance()
    }
  }

  @Builder
  RequestTypeFilterInstance() {
    Column() {
      Filter({
        multiFilters: this.getRequestFilterParams(),
        onFilterChanged: (filterResults: FilterResult[]) => {
          this.applyRequestFilterResults(filterResults);
        },
        filterType: FilterType.LIST_FILTER
      }) {
        Column()
          .width('100%')
          .height(1)
      }
    }
    .height(REVIEW_FILTER_CONTROL_HEIGHT)
    .width('100%')
    .clip(true)
  }

  @Builder
  RefreshButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing && !this.submitting }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.refreshing ? '刷新中' : '刷新')
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
    .layoutWeight(1)
    .backgroundColor(this.refreshing || this.submitting ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.refreshing && !this.submitting)
    .onClick(() => {
      this.refreshRequests();
    })
  }

  @Builder
  ResetButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing && !this.submitting }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.xmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text('重置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .layoutWeight(1)
    .backgroundColor(AppColors.FieldBackground)
    .border({ width: 1, color: AppColors.Border })
    .enabled(!this.refreshing && !this.submitting)
    .onClick(() => {
      this.resetFilters();
    })
  }

  @Builder
  ListActionButtons() {
    Row({ space: 10 }) {
      this.ResetButton()
      this.RefreshButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
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

      this.RequestTimeRow('设备编号', item.deviceCode)
      this.RequestTimeRow('审核编号', item.id)
      this.RequestTimeRow('操作人', this.getOperatorName(item))
      this.RequestTimeRow('提交时间', this.formatReviewTime(item.submittedAt))
      this.ReasonBlock(item.reason)

      Column({ space: 8 }) {
        ForEach(item.changes, (change: DeviceArchiveRequestFieldDiff) => {
          this.ChangeDiffRow(change)
        }, (change: DeviceArchiveRequestFieldDiff) => `${item.id}-${change.field}`)
      }
      .width('100%')

      this.SelectRequestButton(item)
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: this.selectedRequestId === item.id ? 2 : 1,
      color: this.selectedRequestId === item.id ? AppColors.Primary : AppColors.Divider
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
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  ReasonBlock(value: string) {
    Column({ space: 4 }) {
      Text('原因')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text(this.normalizeReasonText(value))
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .lineHeight(19)
        .maxLines(3)
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
  ChangeDiffRow(change: DeviceArchiveRequestFieldDiff) {
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

        Text(this.selectedRequestId === item.id ? '已选择' : '选择')
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
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '审核报告',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.RequestIdField()
        this.DecisionSelector()
        this.ReviewedAtField()
        if (this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}`) {
          this.ReviewCommentField()
        }
      }
      .padding({
        left: 18,
        right: 18,
        top: 18,
        bottom: 18
      })
      .width('100%')
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({ width: 1, color: AppColors.Divider })
      .alignItems(HorizontalAlign.Start)

      this.PasswordSection()
      this.MessageText()
      this.ReviewSubmitButton()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RequestIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('审核编号')

      TextInput({
        placeholder: '请选择待审核操作',
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
      this.FieldTitle('审核结果')

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
    .enabled(this.hasSelectedRequest() && !this.submitting)
    .onClick(() => {
      this.reviewDecision = `${decision}`;
      this.message = '';
      this.messageTone = UiFeedbackTone.Danger;
      this.updateReviewReady();
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

        Text(this.reviewedAt.length > 0 ? this.reviewedAt : '请选择审核时间')
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
        if (!this.hasSelectedRequest() || this.submitting) {
          return;
        }

        this.showReviewedAtPicker();
        this.message = '';
        this.messageTone = UiFeedbackTone.Danger;
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
        placeholder: '请输入审核意见',
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
        .enabled(this.hasSelectedRequest() && !this.submitting)
        .onChange((value: string) => {
          this.reviewComment = value;
          this.message = '';
          this.messageTone = UiFeedbackTone.Danger;
          this.updateReviewReady();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PasswordSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '密码',
        subtitle: ''
      })

      TextInput({
        placeholder: '请输入密码',
        text: this.password
      })
        .type(InputType.Password)
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(this.hasSelectedRequest() && !this.submitting)
        .onChange((value: string) => {
          if (!this.hasSelectedRequest() || this.submitting) {
            return;
          }

          this.password = value;
          this.message = '';
          this.messageTone = UiFeedbackTone.Danger;
          this.updateReviewReady();
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
          .fontColor([AppColors.Warning])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.WarningSurface)

      Text('暂无待审核操作')
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
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({ width: 1, color: AppColors.Divider })
    .alignItems(HorizontalAlign.Center)
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
      InlineMessageSurface({
        message: this.refreshMessage,
        tone: this.refreshMessageTone
      })
    }
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: this.messageTone
      })
    }
  }

  @Builder
  ReviewSubmitButton() {
    Button({ type: ButtonType.Capsule, stateEffect: this.isReviewActionEnabled() }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.getSubmitButtonLabel())
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
    .backgroundColor(this.isReviewActionEnabled() ? AppColors.Primary : AppColors.Disabled)
    .enabled(this.isReviewActionEnabled())
    .onClick(() => {
      this.submitReview();
    })
  }

  async refreshRequests(clearMessage: boolean = true): Promise<void> {
    if (this.refreshing || this.submitting) {
      return;
    }

    if (!this.canReview()) {
      this.refreshMessage = UiFeedbackService.operationUnavailable('审核');
      this.refreshMessageTone = UiFeedbackTone.Danger;
      return;
    }

    this.refreshing = true;
    const response = await DeviceArchiveReviewService.listPendingReviewsRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.refreshMessage = UiFeedbackService.operationError(error, '刷新');
      this.refreshMessageTone = UiFeedbackTone.Danger;
      return;
    }

    this.allRequests = response.data === undefined ? [] : response.data.items;
    this.applyRequestFilters();
    if (this.selectedRequestId.length > 0 && !this.hasRequest(this.selectedRequestId)) {
      this.clearReviewForm();
    }
    this.updateReviewReady();

    this.refreshMessage = UiFeedbackService.operationSuccess('刷新');
    this.refreshMessageTone = UiFeedbackTone.Success;
    if (clearMessage) {
      this.message = '';
      this.messageTone = UiFeedbackTone.Danger;
    }
  }

  selectRequest(item: DeviceArchiveReviewItem): void {
    if (this.selectedRequestId === item.id) {
      this.clearReviewForm();
      this.message = '';
      this.messageTone = UiFeedbackTone.Danger;
      return;
    }

    this.selectedRequestId = item.id;
    this.reviewDecision = '';
    this.reviewComment = '';
    this.reviewedAt = '';
    this.password = '';
    this.message = '';
    this.messageTone = UiFeedbackTone.Danger;
    this.updateReviewReady();
  }

  applyRequestFilters(): void {
    const typeValue = REVIEW_TYPE_FILTER_VALUES[this.requestTypeFilterIndex];
    this.requests = this.allRequests.filter((item: DeviceArchiveReviewItem) => {
      return typeValue.length === 0 || item.type === typeValue;
    });
  }

  resetFilters(): void {
    this.requestTypeFilterIndex = 0;
    this.refreshMessage = '';
    this.refreshMessageTone = UiFeedbackTone.Danger;
    this.filterResetRevision += 1;
    this.applyRequestFilters();
  }

  applyRequestFilterResults(filterResults: FilterResult[]): void {
    const result = filterResults.find((item: FilterResult) => {
      return item.name === '操作类型';
    });
    this.requestTypeFilterIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, REVIEW_TYPE_FILTER_VALUES.length);
    this.applyRequestFilters();
  }

  getRequestFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('操作类型', REVIEW_TYPE_FILTER_OPTIONS)
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
    try {
      const verified = await this.verifyPasswordForSubmit(this.password);
      if (!verified) {
        return;
      }

      const decision = this.reviewDecision as DeviceArchiveReviewDecision;
      const response = await DeviceArchiveReviewService.reviewArchiveRequestRemoteFirst({
        requestId: this.selectedRequestId,
        decision,
        reviewedAt: this.reviewedAt,
        reviewComment: this.reviewComment
      });

      if (!response.success) {
        const error = response.error;
        this.message = UiFeedbackService.operationError(error, '审核');
        this.messageTone = UiFeedbackTone.Danger;
        return;
      }

      this.message = UiFeedbackService.operationSuccess('审核');
      this.messageTone = UiFeedbackTone.Success;
      this.clearReviewForm();
      await this.refreshRequests(false);
    } finally {
      this.submitting = false;
    }
  }

  canSubmitReview(): boolean {
    return this.isReviewActionEnabled();
  }

  isReviewActionEnabled(): boolean {
    return !this.refreshing && !this.submitting && this.reviewReady;
  }

  isReviewFormComplete(): boolean {
    return this.selectedRequestId.length > 0 &&
      this.hasReviewDecision() &&
      this.reviewedAt.length > 0 &&
      this.password.length > 0 &&
      (this.reviewDecision !== `${DeviceArchiveReviewDecision.Rejected}` || this.reviewComment.trim().length > 0);
  }

  fillSubmitValidationMessage(): void {
    if (this.refreshing) {
      this.message = UiFeedbackService.operationUnavailable('审核');
    } else if (!this.canReview()) {
      this.message = UiFeedbackService.operationUnavailable('审核');
    } else if (this.selectedRequestId.length === 0) {
      this.message = UiFeedbackService.requiredSelection('待审核操作');
    } else if (!this.hasReviewDecision()) {
      this.message = UiFeedbackService.requiredSelection('审核结果');
    } else if (this.reviewedAt.length === 0) {
      this.message = UiFeedbackService.requiredTime('审核');
    } else if (this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}` &&
      this.reviewComment.trim().length === 0) {
      this.message = UiFeedbackService.requiredInput('审核意见');
    } else if (this.password.length === 0) {
      this.message = UiFeedbackService.requiredInput('密码');
    } else {
      this.message = UiFeedbackService.operationUnavailable('审核');
    }
    this.messageTone = UiFeedbackTone.Danger;
  }

  clearReviewForm(): void {
    this.selectedRequestId = '';
    this.reviewDecision = '';
    this.reviewComment = '';
    this.reviewedAt = '';
    this.password = '';
    this.updateReviewReady();
  }

  canReview(): boolean {
    return SessionStore.hasPermission(PermissionCode.ReviewCenterDeviceArchiveRequestReview);
  }

  hasRequest(requestId: string): boolean {
    return this.requests.some((item: DeviceArchiveReviewItem) => {
      return item.id === requestId;
    });
  }

  hasSelectedRequest(): boolean {
    return this.selectedRequestId.length > 0;
  }

  hasReviewDecision(): boolean {
    return this.reviewDecision === `${DeviceArchiveReviewDecision.Approved}` ||
      this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}`;
  }

  getOperatorName(item: DeviceArchiveReviewItem): string {
    return item.operatorName === undefined || item.operatorName.length === 0 ? '-' : item.operatorName;
  }

  normalizeReasonText(value: string): string {
    const reason = value.trim();
    return reason.length === 0 ? '-' : reason;
  }

  getSubmitButtonLabel(): string {
    return this.submitting ? '提交中' : '提交报告';
  }

  async verifyPasswordForSubmit(password: string): Promise<boolean> {
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(password);
    if (response.success && response.data === true) {
      return true;
    }

    this.message = UiFeedbackService.passwordVerificationError(response.error, '审核');
    this.messageTone = UiFeedbackTone.Danger;
    return false;
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
    if (!this.hasSelectedRequest() || this.submitting) {
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
        this.messageTone = UiFeedbackTone.Danger;
        this.updateReviewReady();
      }
    });
  }

  updateReviewReady(): void {
    this.reviewReady = this.isReviewFormComplete();
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

  backToReviewCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/ReviewCenter/ReviewCenter', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}


