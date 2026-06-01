import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
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

const DEVICE_ARCHIVE_REVIEW_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '变更审核',
    items: [
      {
        label: '审核对象',
        description: '处理待审核的设备档案修改、添加和删除申请，审核前应核对设备编号、申请原因和字段差异'
      },
      {
        label: '通过',
        description: '确认申请依据充分且内容正确后提交通过结果，由后端统一应用档案变更'
      },
      {
        label: '驳回',
        description: '发现申请依据不足、字段不准确或存在风险时提交驳回结果，并填写可追溯的审核意见'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveReview {
  @State requests: DeviceArchiveReviewItem[] = [];
  @State selectedRequestId: string = '';
  @State reviewDecision: string = '';
  @State reviewedAt: string = '';
  @State reviewComment: string = '';
  @State message: string = '';
  @State messageTone: string = '#D9480F';
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;
  @State submitting: boolean = false;
  private reviewInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '变更审核说明',
      sections: DEVICE_ARCHIVE_REVIEW_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.MgmtArchiveChangeReview)) {
      return;
    }

    this.reviewedAt = this.formatDateTime(new Date());
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
          this.ReviewForm()
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
    .backgroundColor('#F2F5F7')
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
          .fontColor(['#111827'])
      }
      .width(44)
      .height(44)
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#E5E7EB' })
      .onClick(() => {
        this.backToWorkbench();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor('#F2F5F7')
  }

  @Builder
  ModeHeader() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('变更审核')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.reviewInfoDialogController.open();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('审核待处理设备档案申请')
        .fontSize(15)
        .fontColor('#6B7280')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 0, bottom: 2 })
  }

  @Builder
  RequestListPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('待审核申请')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
          .maxLines(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .backgroundColor('#2F6FED')
        .enabled(!this.refreshing && !this.submitting)
        .onClick(() => {
          this.refreshRequests();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.requests.length === 0) {
        this.EmptyState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.requests, (item: DeviceArchiveReviewItem) => {
            this.RequestItem(item)
          }, (item: DeviceArchiveReviewItem) => item.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RequestItem(item: DeviceArchiveReviewItem) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph(this.getRequestTypeIcon(item.type))
            .fontSize(23)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(DeviceArchiveReviewService.getRequestTypeTone(item.type))

        Column({ space: 4 }) {
          Text(item.deviceCode)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.deviceName)
            .fontSize(13)
            .fontColor('#6B7280')
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

      Row() {
        Text(DeviceArchiveReviewService.formatRequestType(item.type))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(DeviceArchiveReviewService.getRequestTypeTone(item.type))
          .layoutWeight(1)
          .maxLines(1)

        Text(item.submittedAt)
          .fontSize(12)
          .fontColor('#6B7280')
          .maxLines(1)
      }
      .width('100%')

      Text(item.reason)
        .fontSize(14)
        .fontColor('#374151')
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

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
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({
      width: this.selectedRequestId === item.id ? 2 : 0,
      color: this.selectedRequestId === item.id ? '#2F6FED' : '#00000000'
    })
  }

  @Builder
  ChangeDiffRow(change: DeviceArchiveChangeFieldDiff) {
    Column({ space: 4 }) {
      Text(change.label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .maxLines(1)

      Text(`${change.oldValue} -> ${change.newValue}`)
        .fontSize(13)
        .fontColor('#6B7280')
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
    .backgroundColor('#F7F9FC')
    .borderRadius(14)
  }

  @Builder
  SelectRequestButton(item: DeviceArchiveReviewItem) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(this.selectedRequestId === item.id ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.text_clipboard'))
          .fontSize(18)
          .fontColor(['#FFFFFF'])

        Text(this.selectedRequestId === item.id ? '已选择' : '选择审核')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(46)
    .width('100%')
    .backgroundColor(this.selectedRequestId === item.id ? '#087F5B' : '#2F6FED')
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
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RequestIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('审核记录编号')

      TextInput({
        placeholder: '请先选择待审核申请',
        text: this.selectedRequestId
      })
        .height(56)
        .fontSize(16)
        .fontColor(this.selectedRequestId.length > 0 ? '#111827' : '#9CA3AF')
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: '#D6DAE1' })
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
          .fontColor([this.reviewDecision === `${decision}` ? '#FFFFFF' : '#111827'])

        Text(DeviceArchiveReviewService.formatDecision(decision))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.reviewDecision === `${decision}` ? '#FFFFFF' : '#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(46)
    .layoutWeight(1)
    .backgroundColor(this.reviewDecision === `${decision}` ? this.getDecisionTone(decision) : '#F7F9FC')
    .border({
      width: 1,
      color: this.reviewDecision === `${decision}` ? this.getDecisionTone(decision) : '#D6DAE1'
    })
    .enabled(!this.submitting)
    .onClick(() => {
      this.reviewDecision = `${decision}`;
      this.message = '';
      this.messageTone = '#D9480F';
    })
  }

  @Builder
  ReviewedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('审核时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor(['#111827'])

        Text(this.reviewedAt.length > 0 ? this.reviewedAt : '选择审核时间')
          .fontSize(16)
          .fontColor(this.reviewedAt.length > 0 ? '#111827' : '#9CA3AF')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor(['#6B7280'])
      }
      .height(56)
      .width('100%')
      .backgroundColor('#F7F9FC')
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .border({ width: 1, color: '#D6DAE1' })
      .onClick(() => {
        this.showReviewedAtPicker();
        this.message = '';
        this.messageTone = '#D9480F';
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({ width: 1, color: '#D6DAE1' })
        .enabled(!this.submitting)
        .onChange((value: string) => {
          this.reviewComment = value;
          this.message = '';
          this.messageTone = '#D9480F';
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
          .fontColor(['#2F6FED'])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor('#EEF4FF')

      Text('暂无待审核申请')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 28,
      bottom: 28
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('审核状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '待审核数量', value: `${this.requests.length}项`, tone: '#374151' })
        this.CardDivider()
        StatusInfoRow({
          label: '当前申请',
          value: this.selectedRequestId.length > 0 ? this.selectedRequestId : '-',
          tone: this.selectedRequestId.length > 0 ? '#2F6FED' : '#374151'
        })
        this.CardDivider()
        StatusInfoRow({
          label: '刷新状态',
          value: this.isFailureMessageVisible() ? '处理失败' : this.refreshStatus,
          tone: this.isFailureMessageVisible() ? '#D9480F' : '#087F5B'
        })
        this.CardDivider()
        StatusInfoRow({
          label: '服务状态',
          value: ApiClient.getRuntimeStatusLabel(),
          tone: ApiClient.getRuntimeStatusTone()
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
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
      .fontColor('#111827')
      .maxLines(1)
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
          .fontColor(['#FFFFFF'])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(enabled ? '#2F6FED' : '#AEB6C2')
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  @Builder
  InfoButton(action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor(['#111827'])
    }
    .width(28)
    .height(28)
    .backgroundColor('#00000000')
    .onClick(() => {
      action();
    })
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor('#E5E7EB')
      .margin({ left: 18, right: 18 })
  }

  async refreshRequests(clearMessage: boolean = true): Promise<void> {
    if (this.refreshing || this.submitting) {
      return;
    }

    if (!this.canReview()) {
      this.message = '当前账号无权审核设备档案变更';
      this.messageTone = '#D9480F';
      return;
    }

    this.refreshing = true;
    const response = await DeviceArchiveReviewService.listPendingReviewsRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '变更申请刷新失败';
      this.messageTone = '#D9480F';
      this.refreshStatus = '刷新失败';
      return;
    }

    this.requests = response.data === undefined ? [] : response.data.items;
    if (this.selectedRequestId.length > 0 && !this.hasRequest(this.selectedRequestId)) {
      this.clearReviewForm();
    }

    if (clearMessage) {
      this.message = '';
      this.messageTone = '#D9480F';
    }
    this.refreshStatus = '已刷新';
  }

  selectRequest(item: DeviceArchiveReviewItem): void {
    this.selectedRequestId = item.id;
    this.reviewDecision = '';
    this.reviewComment = '';
    if (this.reviewedAt.length === 0) {
      this.reviewedAt = this.formatDateTime(new Date());
    }
    this.message = '';
    this.messageTone = '#D9480F';
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
      this.message = error ? error.message : '变更审核失败';
      this.messageTone = '#D9480F';
      return;
    }

    this.message = `${DeviceArchiveReviewService.formatDecision(decision)}完成`;
    this.messageTone = '#087F5B';
    this.refreshStatus = '已更新';
    this.clearReviewForm();
    await this.refreshRequests(false);
  }

  canSubmitReview(): boolean {
    return this.canReview() && !this.refreshing && !this.submitting &&
      this.selectedRequestId.length > 0 &&
      this.reviewDecision.length > 0 &&
      this.reviewedAt.length > 0 &&
      (this.reviewDecision !== `${DeviceArchiveReviewDecision.Rejected}` || this.reviewComment.trim().length > 0);
  }

  fillSubmitValidationMessage(): void {
    if (this.selectedRequestId.length === 0) {
      this.message = '请先选择待审核申请';
    } else if (this.reviewDecision.length === 0) {
      this.message = '请选择审核结论';
    } else if (this.reviewedAt.length === 0) {
      this.message = '请选择审核时间';
    } else if (this.reviewDecision === `${DeviceArchiveReviewDecision.Rejected}` &&
      this.reviewComment.trim().length === 0) {
      this.message = '驳回申请时必须填写审核意见';
    } else {
      this.message = '当前不可提交审核结果';
    }
    this.messageTone = '#D9480F';
  }

  clearReviewForm(): void {
    this.selectedRequestId = '';
    this.reviewDecision = '';
    this.reviewComment = '';
    this.reviewedAt = this.formatDateTime(new Date());
  }

  canReview(): boolean {
    return SessionStore.hasPermission(PermissionCode.MgmtArchiveChangeReview);
  }

  hasRequest(requestId: string): boolean {
    return this.requests.some((item: DeviceArchiveReviewItem) => {
      return item.id === requestId;
    });
  }

  isFailureMessageVisible(): boolean {
    return this.message.length > 0 && this.messageTone === '#D9480F';
  }

  getSubmitButtonLabel(): string {
    return this.submitting ? '提交中' : '提交审核结果';
  }

  getDecisionTone(decision: DeviceArchiveReviewDecision): string {
    return decision === DeviceArchiveReviewDecision.Approved ? '#087F5B' : '#D9480F';
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

  showReviewedAtPicker(): void {
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.reviewedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.reviewedAt = this.formatDateTime(value);
        this.message = '';
        this.messageTone = '#D9480F';
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
      this.message = '页面跳转失败';
      this.messageTone = '#D9480F';
    }
  }
}
