import { Filter, FilterParams, FilterResult, FilterType } from '@kit.ArkUI';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { PermissionCode } from '../../models/identity/PermissionModels';
import {
  OperationReviewDecision,
  OperationReviewItem,
  OperationReviewRequestType
} from '../../models/management/OperationReviewModels';
import { OperationReviewService } from '../../services/management/OperationReviewService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

const OPERATION_REVIEW_TYPE_OPTIONS: string[] = ['全部类型', '维修报告', '复检记录'];
const OPERATION_REVIEW_TYPE_VALUES: string[] = ['', 'REPAIR_REPORT', 'REINSPECTION_RECORD'];
const REVIEW_FILTER_CONTROL_HEIGHT = 56;

@Entry
@Component
struct OperationsReview {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State requests: OperationReviewItem[] = [];
  @State requestTypeFilterIndex: number = 0;
  @State keyword: string = '';
  @State selectedRequestId: string = '';
  @State reviewDecision: string = '';
  @State reviewedAt: string = '';
  @State reviewComment: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State refreshMessage: string = '';
  @State refreshMessageTone: string = AppColors.Danger;
  @State refreshing: boolean = false;
  @State submitting: boolean = false;
  @State reviewReady: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ManagementCenterOperationsReview)) {
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
    this.backToManagementCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToManagementCenter();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text('运维审核')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Operations Review')
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
        title: '待审核运维列表',
        subtitle: ''
      })

      Column({ space: 14 }) {
        this.SearchPanel()

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

        this.RefreshMessageText()
        this.RefreshButton()
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
  SearchPanel() {
    TextInput({ placeholder: '输入设备编号、设备名称或报告编号搜索', text: this.keyword })
      .height(52)
      .fontSize(15)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .border({ width: 1, color: AppColors.Border })
      .enabled(!this.refreshing && !this.submitting)
      .onChange((value: string) => {
        this.keyword = value;
      })
      .width('100%')
  }

  @Builder
  RefreshButton() {
    Button({ type: ButtonType.Capsule, stateEffect: !this.refreshing && !this.submitting }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.refreshing ? '刷新中' : '刷新申请')
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
    .backgroundColor(this.refreshing || this.submitting ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.refreshing && !this.submitting)
    .onClick(() => {
      this.refreshRequests();
    })
  }

  @Builder
  RequestFilterResultList() {
    Column({ space: 12 }) {
      if (this.requests.length === 0) {
        this.EmptyState()
      } else {
        ForEach(this.requests, (item: OperationReviewItem) => {
          this.RequestItem(item)
        }, (item: OperationReviewItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  RequestItem(item: OperationReviewItem) {
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
        .backgroundColor(OperationReviewService.getRequestTypeTone(item.type))

        Column({ space: 4 }) {
          Text(OperationReviewService.formatRequestType(item.type))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.targetNo)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(OperationReviewService.formatStatus(item.status))
          .fontSize(13)
          .fontColor(OperationReviewService.getStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.RequestFieldRow('设备标准编号', item.deviceCode)
      this.RequestFieldRow('设备名称', item.deviceName)
      this.RequestFieldRow('申请人', this.getApplicantName(item))
      this.RequestFieldRow('提交时间', this.formatReviewTime(item.submittedAt))

      if (item.summary.length > 0) {
        Text(item.summary)
          .fontSize(14)
          .fontColor(AppColors.TextSecondary)
          .lineHeight(20)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

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
  RequestFieldRow(label: string, value: string) {
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
  SelectRequestButton(item: OperationReviewItem) {
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
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '审核结果',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.RequestIdField()
        this.DecisionSelector()
        this.ReviewedAtField()
        if (this.reviewDecision === `${OperationReviewDecision.Rejected}`) {
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

      this.MessageText()
      this.ReviewSubmitButton()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RequestIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('运维审核编号')

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
        this.DecisionOption(OperationReviewDecision.Approved, $r('sys.symbol.checkmark_circle'))
        this.DecisionOption(OperationReviewDecision.Rejected, $r('sys.symbol.xmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DecisionOption(decision: OperationReviewDecision, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.reviewDecision === `${decision}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(OperationReviewService.formatDecision(decision))
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
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无待审核运维申请')
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
      this.refreshMessage = '当前账号无权审核运维申请';
      this.refreshMessageTone = AppColors.Danger;
      return;
    }

    this.refreshing = true;
    const response = await OperationReviewService.listPendingReviewsRemoteFirst(
      OPERATION_REVIEW_TYPE_VALUES[this.requestTypeFilterIndex],
      this.keyword);
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.refreshMessage = error ? error.message : '运维申请刷新失败';
      this.refreshMessageTone = AppColors.Danger;
      return;
    }

    this.requests = response.data === undefined ? [] : response.data.items;
    if (this.selectedRequestId.length > 0 && !this.hasRequest(this.selectedRequestId)) {
      this.clearReviewForm();
    }
    this.updateReviewReady();

    this.refreshMessage = '';
    this.refreshMessageTone = AppColors.Danger;
    if (clearMessage) {
      this.message = '';
      this.messageTone = AppColors.Danger;
    }
  }

  selectRequest(item: OperationReviewItem): void {
    this.selectedRequestId = item.id;
    this.reviewDecision = '';
    this.reviewComment = '';
    this.reviewedAt = '';
    this.message = '';
    this.messageTone = AppColors.Danger;
    this.updateReviewReady();
  }

  applyRequestFilterResults(filterResults: FilterResult[]): void {
    const result = filterResults.find((item: FilterResult) => {
      return item.name === '申请类型';
    });
    this.requestTypeFilterIndex = result === undefined ? 0 :
      this.normalizeFilterIndex(result.index, OPERATION_REVIEW_TYPE_VALUES.length);
    this.refreshRequests();
  }

  getRequestFilterParams(): FilterParams[] {
    return [
      this.createFilterParams('申请类型', OPERATION_REVIEW_TYPE_OPTIONS)
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
    const decision = this.reviewDecision as OperationReviewDecision;
    const response = await OperationReviewService.reviewOperationRequestRemoteFirst({
      requestId: this.selectedRequestId,
      decision,
      reviewedAt: this.reviewedAt,
      reviewComment: this.reviewComment
    });
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '运维审核失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.message = `${OperationReviewService.formatDecision(decision)}完成`;
    this.messageTone = AppColors.Success;
    this.clearReviewForm();
    await this.refreshRequests(false);
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
      (this.reviewDecision !== `${OperationReviewDecision.Rejected}` || this.reviewComment.trim().length > 0);
  }

  fillSubmitValidationMessage(): void {
    if (this.refreshing) {
      this.message = '申请列表正在刷新，请稍后提交审核结果';
    } else if (!this.canReview()) {
      this.message = '当前账号无权审核运维申请';
    } else if (this.selectedRequestId.length === 0) {
      this.message = '请先选择待审核申请';
    } else if (!this.hasReviewDecision()) {
      this.message = '请选择审核结论';
    } else if (this.reviewedAt.length === 0) {
      this.message = '请选择审核时间';
    } else if (this.reviewDecision === `${OperationReviewDecision.Rejected}` &&
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
    this.updateReviewReady();
  }

  canReview(): boolean {
    return SessionStore.hasPermission(PermissionCode.ManagementCenterOperationsReview);
  }

  hasRequest(requestId: string): boolean {
    return this.requests.some((item: OperationReviewItem) => {
      return item.id === requestId;
    });
  }

  hasReviewDecision(): boolean {
    return this.reviewDecision === `${OperationReviewDecision.Approved}` ||
      this.reviewDecision === `${OperationReviewDecision.Rejected}`;
  }

  getApplicantName(item: OperationReviewItem): string {
    return item.applicantName === undefined || item.applicantName.length === 0 ? '-' : item.applicantName;
  }

  getSubmitButtonLabel(): string {
    return this.submitting ? '提交中' : '提交审核结果';
  }

  getDecisionTone(decision: OperationReviewDecision): string {
    return decision === OperationReviewDecision.Approved ? AppColors.Success : AppColors.Danger;
  }

  getRequestTypeIcon(type: OperationReviewRequestType): Resource {
    switch (type) {
      case OperationReviewRequestType.ReinspectionRecord:
        return $r('sys.symbol.doc_text_badge_checkmark');
      case OperationReviewRequestType.RepairReport:
      default:
        return $r('sys.symbol.wrench_and_screwdriver');
    }
  }

  formatReviewTime(value: string): string {
    const normalized = value.trim();
    if (normalized.length === 0) {
      return '-';
    }

    return normalized.replace('T', ' ').replace('Z', '').split('.')[0];
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

  backToManagementCenter(): void {
    if (!MainPageNavigator.backOrReplace(this.getUIContext(), 'pages/ManagementCenter/ManagementCenter')) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
