import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import { StatusInfoRow } from '../components/StatusInfoRow';
import { DeviceArchiveChangeRequestStatus } from '../models/DeviceArchiveChangeModels';
import {
  DeviceArchiveChangeFieldDiff,
  DeviceArchiveReviewDecision,
  DeviceArchiveReviewItem
} from '../models/DeviceArchiveReviewModels';
import { ApiClient } from '../services/ApiClient';
import { DeviceArchiveReviewService } from '../services/DeviceArchiveReviewService';
import { SessionStore } from '../stores/SessionStore';
import { AuthGuard } from '../utils/AuthGuard';

const DEVICE_ARCHIVE_REVIEW_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '变更审核',
    items: [
      {
        label: '审核对象',
        description: '只处理已提交且尚未审核的设备档案变更申请'
      },
      {
        label: '通过',
        description: '审核通过后将变更写入正式档案，并进入变更冻结期'
      },
      {
        label: '驳回',
        description: '审核驳回后不修改正式档案，设备解除待审核锁定'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveReview {
  @State requests: DeviceArchiveReviewItem[] = [];
  @State reviewComment: string = '';
  @State message: string = '';
  @State messageTone: string = '#D9480F';
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;
  @State reviewingRequestId: string = '';
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
    if (!AuthGuard.requireAuthenticated(this.getUIContext())) {
      return;
    }

    if (!this.canReview()) {
      this.message = '当前账号无权审核设备档案变更';
      this.messageTone = '#D9480F';
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
          this.ReviewCommentPanel()
          this.RequestListPanel()
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

      Text('审核待处理设备档案变更')
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
  ReviewCommentPanel() {
    Column({ space: 12 }) {
      this.FieldTitle('审核意见')

      TextArea({
        placeholder: '填写审核意见；驳回申请时必填',
        text: this.reviewComment
      })
        .height(104)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(300)
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({ width: 1, color: '#D6DAE1' })
        .onChange((value: string) => {
          this.reviewComment = value;
          this.message = '';
        })

      this.MessageText()
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
        .enabled(!this.refreshing && this.reviewingRequestId.length === 0)
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
      Row() {
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

      Row({ space: 10 }) {
        Column() {
          this.ReviewButton('通过', $r('sys.symbol.checkmark_circle'), '#2F6FED',
            this.canSubmitReview(item.id), () => {
              this.reviewRequest(item.id, DeviceArchiveReviewDecision.Approved);
            })
        }
        .layoutWeight(1)

        Column() {
          this.ReviewButton('驳回', $r('sys.symbol.xmark_circle'), '#D9480F',
            this.canSubmitReview(item.id), () => {
              this.reviewRequest(item.id, DeviceArchiveReviewDecision.Rejected);
            })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
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
  ReviewButton(label: string, icon: Resource, color: string, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor(['#FFFFFF'])

        Text(label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(48)
    .width('100%')
    .backgroundColor(enabled ? color : '#AEB6C2')
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
      .margin({
        left: 18,
        right: 18
      })
  }

  async refreshRequests(clearMessage: boolean = true): Promise<void> {
    if (this.refreshing || this.reviewingRequestId.length > 0) {
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
    if (clearMessage) {
      this.message = '';
    }
    this.refreshStatus = '已刷新';
  }

  async reviewRequest(requestId: string, decision: DeviceArchiveReviewDecision): Promise<void> {
    if (!this.canSubmitReview(requestId)) {
      return;
    }

    this.reviewingRequestId = requestId;
    const response = await DeviceArchiveReviewService.reviewChangeRequestRemoteFirst({
      requestId,
      decision,
      reviewComment: this.reviewComment
    });
    this.reviewingRequestId = '';

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '变更审核失败';
      this.messageTone = '#D9480F';
      return;
    }

    this.reviewComment = '';
    this.message = `${DeviceArchiveReviewService.formatDecision(decision)}完成`;
    this.messageTone = '#087F5B';
    this.refreshStatus = '已刷新';
    await this.refreshRequests(false);
  }

  canSubmitReview(requestId: string): boolean {
    return this.canReview() && !this.refreshing &&
      (this.reviewingRequestId.length === 0 || this.reviewingRequestId === requestId);
  }

  canReview(): boolean {
    return SessionStore.hasPermission('DEVICE_CHANGE_REVIEW');
  }

  isFailureMessageVisible(): boolean {
    return this.message.length > 0 && this.messageTone === '#D9480F';
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
