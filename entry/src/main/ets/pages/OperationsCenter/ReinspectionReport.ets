import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import {
  OperationReportBottomContentPadding,
  OperationReportTab,
  OperationReportTabBar
} from '../../components/OperationReportTabBar';
import { FaultSeverity } from '../../models/operations/FaultModels';
import {
  ReinspectionRecordForm,
  ReinspectionResult,
  ReinspectionTaskStatus,
  ReinspectionTaskSummary
} from '../../models/operations/ReinspectionModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { ApiClient } from '../../services/common/ApiClient';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { AuthService } from '../../services/identity/AuthService';
import { ReinspectionService } from '../../services/operations/ReinspectionService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { AppNavigator } from '../../utils/AppNavigator';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

@Entry
@Component
struct ReinspectionReport {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State allTaskItems: ReinspectionTaskSummary[] = [];
  @State taskItems: ReinspectionTaskSummary[] = [];
  @State taskId: string = '';
  @State result: string = '';
  @State reinspectedAt: string = '';
  @State description: string = '';
  @State password: string = '';
  @State taskMessage: string = '';
  @State taskMessageTone: string = UiFeedbackTone.Danger;
  @State recordMessage: string = '';
  @State recordMessageTone: string = UiFeedbackTone.Danger;
  @State normalizedTaskId: string = '-';
  @State submittedReinspectionTaskId: string = '';
  @State refreshing: boolean = false;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requireAllPermissions(this.getUIContext(), [
      PermissionCode.OperationsCenterReinspectionTaskAccept,
      PermissionCode.OperationsCenterReinspectionReportSubmit
    ])) {
      return;
    }

    this.refreshTasks();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          this.PageTitleBar()

          Column({ space: 18 }) {
            this.ModeHeader()
            this.TaskListPanel()
            this.RecordForm()
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .padding({
            left: AppSpacing.PageX,
            right: AppSpacing.PageX,
            top: 0,
            bottom: OperationReportBottomContentPadding
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

      OperationReportTabBar({
        currentTab: OperationReportTab.Reinspection,
        repairEnabled: this.canOpenRepairReport(),
        reinspectionEnabled: this.canOpenReinspectionReport(),
        onRepairClick: () => {
          this.openRepairReport();
        },
        onReinspectionClick: () => {
        }
      })
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToOperationsCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToOperationsCenter();
      }
    })
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('复检任务')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Reinspection Task Report')
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
  TaskListPanel() {
    Column({ space: 10 }) {
      AppSectionTitle({
        title: '复检任务列表',
        subtitle: ''
      })

      this.TaskResultPanel()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  TaskResultPanel() {
    Column({ space: 12 }) {
      this.TaskMessageText()
      this.ActionButton(this.refreshing ? '刷新中' : '刷新', $r('sys.symbol.arrow_clockwise'),
        !this.refreshing && !this.submitting, () => {
          this.refreshTasks();
        })

      if (this.taskItems.length === 0) {
        this.EmptyTaskState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.taskItems, (item: ReinspectionTaskSummary) => {
            this.TaskItem(item)
          }, (item: ReinspectionTaskSummary) => item.id)
        }
        .width('100%')
      }
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

  @Builder
  EmptyTaskState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.doc_text_badge_checkmark'))
          .fontSize(36)
          .fontColor([AppColors.Success])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.SuccessSurface)

      Text('暂无复检任务')
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
  TaskItem(item: ReinspectionTaskSummary) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.doc_text_badge_checkmark'))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(ReinspectionService.getSeverityTone(item.severity))

        Column({ space: 4 }) {
          Text(item.deviceName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(ReinspectionService.formatTaskStatus(item.status))
          .fontSize(13)
          .fontColor(this.getTaskStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.TaskFieldRow('任务编号', item.taskNo)
      this.TaskFieldRow('位置', item.location)
      this.TaskFieldRow('严重程度', ReinspectionService.formatSeverity(item.severity))

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.isTaskSelected(item) ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.text_clipboard'))
            .fontSize(18)
            .fontColor([AppColors.OnPrimary])

          Text(this.isTaskSelected(item) ? '已选择' : '填写复检报告')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.OnPrimary)
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width('100%')
      }
      .height(46)
      .width('100%')
      .backgroundColor(this.isTaskSelected(item) ? AppColors.Success : AppColors.Primary)
      .onClick(() => {
        this.selectTask(item);
      })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: this.isTaskSelected(item) ? 2 : 1,
      color: this.isTaskSelected(item) ? AppColors.Primary : AppColors.Divider
    })
  }

  @Builder
  TaskFieldRow(label: string, value: string) {
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
  RecordForm() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '复检报告',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.TaskIdField()
        this.ResultSelector()
        this.ReinspectedAtField()
        this.DescriptionField()
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
      this.RecordMessageText()
      this.ActionButton(this.getSubmitButtonLabel(), this.getSubmitIcon(), this.canSubmitRecord(),
        () => {
          this.submitRecord();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TaskIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('复检任务编号')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.text_clipboard'))
          .fontSize(20)
          .fontColor([this.taskId.length > 0 ? AppColors.TextPrimary : AppColors.TextSecondary])

        Text(this.taskId.length > 0 ? this.taskId : '请选择复检任务')
          .fontSize(16)
          .fontColor(this.taskId.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(56)
      .width('100%')
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .padding({
        left: 16,
        right: 16
      })
      .border({
        width: 1,
        color: AppColors.Border
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('复检结果')

      Row({ space: 10 }) {
        this.ResultOption(ReinspectionResult.Passed, $r('sys.symbol.checkmark_circle'))
        this.ResultOption(ReinspectionResult.Failed, $r('sys.symbol.xmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultOption(result: ReinspectionResult, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.result === `${result}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(ReinspectionService.formatResult(result))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.result === `${result}` ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(
      this.result === `${result}` ? ReinspectionService.getResultTone(result) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.result === `${result}` ? ReinspectionService.getResultTone(result) : AppColors.Border
    })
    .enabled(this.canSubmitRecord())
    .onClick(() => {
      this.result = `${result}`;
      this.recordMessage = '';
      this.recordMessageTone = UiFeedbackTone.Danger;
    })
  }

  @Builder
  ReinspectedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('复检时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.reinspectedAt.length > 0 ? this.reinspectedAt : '请选择复检时间')
          .fontSize(16)
          .fontColor(this.reinspectedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
      .padding({
        left: 16,
        right: 16
      })
      .border({
        width: 1,
        color: AppColors.Border
      })
      .onClick(() => {
        if (!this.canSubmitRecord()) {
          return;
        }

        this.showReinspectedAtPicker();
        this.recordMessage = '';
        this.recordMessageTone = UiFeedbackTone.Danger;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('复检说明')

      TextArea({
        placeholder: '请输入复检说明',
        text: this.description
      })
        .height(132)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(800)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .enabled(this.canSubmitRecord())
        .onChange((value: string) => {
          this.description = value;
          this.recordMessage = '';
          this.recordMessageTone = UiFeedbackTone.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
        .enabled(this.canSubmitRecord())
        .onChange((value: string) => {
          if (!this.canSubmitRecord()) {
            return;
          }

          this.password = value;
          this.recordMessage = '';
          this.recordMessageTone = UiFeedbackTone.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TaskMessageText() {
    if (this.taskMessage.length > 0) {
      InlineMessageSurface({
        message: this.taskMessage,
        tone: this.taskMessageTone
      })
    }
  }

  @Builder
  RecordMessageText() {
    if (this.recordMessage.length > 0) {
      InlineMessageSurface({
        message: this.recordMessage,
        tone: this.recordMessageTone
      })
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

  async refreshTasks(): Promise<void> {
    if (this.refreshing || this.submitting) {
      return;
    }

    this.refreshing = true;
    const response = await ReinspectionService.queryPendingTasksRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.taskMessage = UiFeedbackService.operationError(error, '刷新');
      this.taskMessageTone = UiFeedbackTone.Danger;
      return;
    }

    const data = response.data;
    this.allTaskItems = data ? data.items : [];
    this.taskItems = [...this.allTaskItems];
    this.ensureSelectedTaskStillAvailable();
    this.taskMessage = UiFeedbackService.operationSuccess('刷新');
    this.taskMessageTone = UiFeedbackTone.Success;
  }

  async submitRecord(): Promise<void> {
    if (this.submitting || this.isSelectedReinspectionTaskSubmitted()) {
      return;
    }

    const form = this.createReinspectionRecordForm();
    const validation = ReinspectionService.validateRecordForm(form);
    if (!validation.valid) {
      this.recordMessage = validation.message;
      this.recordMessageTone = UiFeedbackTone.Danger;
      return;
    }

    if (this.password.length === 0) {
      this.recordMessage = UiFeedbackService.requiredInput('密码');
      this.recordMessageTone = UiFeedbackTone.Danger;
      return;
    }

    this.submitting = true;
    try {
      const verified = await this.verifyPasswordForSubmit(this.password);
      if (!verified) {
        return;
      }

      const response = await ReinspectionService.submitRecordRemoteFirst(form);
      if (!response.success) {
        const error = response.error;
        this.recordMessage = UiFeedbackService.operationError(error, '提交');
        this.recordMessageTone = UiFeedbackTone.Danger;
        return;
      }

      this.recordMessage = UiFeedbackService.operationSuccess('提交');
      this.recordMessageTone = UiFeedbackTone.Success;
      this.submittedReinspectionTaskId = this.normalizedTaskId;
      this.allTaskItems = this.allTaskItems.filter((item: ReinspectionTaskSummary) => {
        return item.taskNo !== this.normalizedTaskId && item.id !== this.normalizedTaskId;
      });
      this.taskItems = [...this.allTaskItems];
      this.clearSelectedTask();
      this.refreshTasks();
    } finally {
      this.submitting = false;
    }
  }

  createReinspectionRecordForm(): ReinspectionRecordForm {
    return {
      taskId: this.taskId,
      result: this.result as ReinspectionResult,
      reinspectedAt: this.reinspectedAt,
      description: this.description
    };
  }

  async verifyPasswordForSubmit(password: string): Promise<boolean> {
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(password);
    if (response.success && response.data === true) {
      return true;
    }

    this.recordMessage = UiFeedbackService.passwordVerificationError(response.error, '提交');
    this.recordMessageTone = UiFeedbackTone.Danger;
    return false;
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.isSelectedReinspectionTaskSubmitted()) {
      return '已提交';
    }

    return '提交报告';
  }

  getSubmitIcon(): Resource {
    return $r('sys.symbol.checkmark_circle');
  }

  canSubmitRecord(): boolean {
    return !this.submitting && this.taskId.length > 0 && !this.isSelectedReinspectionTaskSubmitted();
  }

  isSelectedReinspectionTaskSubmitted(): boolean {
    return this.submittedReinspectionTaskId.length > 0 && this.normalizedTaskId === this.submittedReinspectionTaskId;
  }

  isTaskSelected(item: ReinspectionTaskSummary): boolean {
    const selectedTaskId = this.normalizedTaskId.trim();
    if (selectedTaskId.length === 0 || selectedTaskId === '-') {
      return false;
    }

    return item.taskNo === selectedTaskId || item.id === selectedTaskId;
  }

  selectTask(item: ReinspectionTaskSummary): void {
    if (this.isTaskSelected(item)) {
      this.clearSelectedTask();
      this.recordMessage = '';
      this.recordMessageTone = UiFeedbackTone.Danger;
      return;
    }

    this.taskId = item.id;
    this.normalizedTaskId = item.id;
    if (this.normalizedTaskId !== this.submittedReinspectionTaskId) {
      this.submittedReinspectionTaskId = '';
    }
    this.recordMessage = '';
    this.recordMessageTone = UiFeedbackTone.Danger;
  }

  clearSelectedTask(): void {
    this.taskId = '';
    this.normalizedTaskId = '-';
    this.result = '';
    this.reinspectedAt = '';
    this.description = '';
    this.password = '';
  }

  ensureSelectedTaskStillAvailable(): void {
    if (this.taskId.length === 0) {
      return;
    }

    const exists = this.taskItems.some((item: ReinspectionTaskSummary) => {
      return item.id === this.taskId || item.taskNo === this.taskId;
    });
    if (!exists) {
      this.clearSelectedTask();
    }
  }

  showReinspectedAtPicker(): void {
    if (!this.canSubmitRecord()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.reinspectedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.reinspectedAt = this.formatDateTime(value);
        this.recordMessage = '';
        this.recordMessageTone = UiFeedbackTone.Danger;
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

  backToOperationsCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/OperationsCenter/OperationsCenter', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }

  canOpenRepairReport(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit);
  }

  canOpenReinspectionReport(): boolean {
    return SessionStore.hasAllPermissions([
      PermissionCode.OperationsCenterReinspectionTaskAccept,
      PermissionCode.OperationsCenterReinspectionReportSubmit
    ]);
  }

  openRepairReport(): void {
    if (!this.canOpenRepairReport()) {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      return;
    }

    AppNavigator.replace(this.getUIContext(), 'pages/OperationsCenter/RepairReport', () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }

  getTaskStatusTone(status: ReinspectionTaskStatus): string {
    switch (status) {
      case ReinspectionTaskStatus.Pending:
        return AppColors.Warning;
      case ReinspectionTaskStatus.Completed:
        return AppColors.Success;
      default:
        return AppColors.TextSecondary;
    }
  }
}
