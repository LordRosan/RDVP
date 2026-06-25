import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { FaultSeverity } from '../../models/operations/FaultModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { RepairReportForm, RepairTaskItem, RepairReportResult, RepairTaskStatus } from '../../models/operations/RepairTaskModels';
import { ApiClient } from '../../services/common/ApiClient';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { AuthService } from '../../services/identity/AuthService';
import { FaultReportService } from '../../services/operations/FaultReportService';
import { RepairTaskService } from '../../services/operations/RepairTaskService';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

@Entry
@Component
struct RepairReport {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State allTaskItems: RepairTaskItem[] = [];
  @State taskItems: RepairTaskItem[] = [];
  @State taskId: string = '';
  @State reportResult: string = '';
  @State repairedAt: string = '';
  @State processDescription: string = '';
  @State password: string = '';
  @State taskMessage: string = '';
  @State taskMessageTone: string = AppColors.Danger;
  @State reportMessage: string = '';
  @State reportMessageTone: string = AppColors.Danger;
  @State normalizedTaskId: string = '-';
  @State submittedRepairTaskId: string = '';
  @State refreshing: boolean = false;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OperationsCenterRepairReportSubmit)) {
      return;
    }

    this.refreshTasks();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.TaskListPanel()
          this.ReportForm()
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
      Text('维修任务')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Repair Task Report')
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
        title: '维修任务列表',
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
      this.ActionButton(this.refreshing ? '刷新中' : '刷新任务', $r('sys.symbol.arrow_clockwise'),
        !this.refreshing && !this.submitting, () => {
          this.refreshTasks();
        })

      if (this.taskItems.length === 0) {
        this.EmptyTaskState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.taskItems, (item: RepairTaskItem) => {
            this.TaskItem(item)
          }, (item: RepairTaskItem) => item.id)
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
        SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
          .fontSize(36)
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无维修任务')
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
  TaskItem(item: RepairTaskItem) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.getSeverityTone(item.severity))

        Column({ space: 4 }) {
          Text(item.deviceName)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.taskNo)
            .fontSize(12)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(FaultReportService.formatFaultType(item.faultType))
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)

        Text(FaultReportService.formatSeverity(item.severity))
          .fontSize(13)
          .fontColor(this.getSeverityTone(item.severity))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.isTaskSelected(item) ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.text_clipboard'))
            .fontSize(18)
            .fontColor([AppColors.OnPrimary])

          Text(this.isTaskSelected(item) ? '已选择' : '填写维修报告')
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
      width: this.isTaskSelected(item) ? 2 : 0,
      color: this.isTaskSelected(item) ? AppColors.Primary : AppColors.Transparent
    })
  }

  @Builder
  ReportForm() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '维修报告',
        subtitle: ''
      })

      Column({ space: 16 }) {
        this.TaskIdField()
        this.ResultSelector()
        this.RepairedAtField()
        this.ProcessDescriptionField()
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
      this.ReportMessageText()
      this.ActionButton(this.getSubmitButtonLabel(), this.getSubmitIcon(), this.canSubmitRepairReport(),
        () => {
          this.submitRepairReport();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TaskIdField() {
    Column({ space: 10 }) {
      this.FieldTitle('维修任务编号')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.text_clipboard'))
          .fontSize(20)
          .fontColor([this.taskId.length > 0 ? AppColors.TextPrimary : AppColors.TextSecondary])

        Text(this.taskId.length > 0 ? this.taskId : '请选择维修任务')
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
      this.FieldTitle('维修结果')

      Row({ space: 10 }) {
        this.ResultOption(RepairReportResult.Repaired, $r('sys.symbol.checkmark_circle'))
        this.ResultOption(RepairReportResult.TemporaryRestored, $r('sys.symbol.wrench_and_screwdriver'))
        this.ResultOption(RepairReportResult.Unresolved, $r('sys.symbol.exclamationmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultOption(result: RepairReportResult, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.reportResult === `${result}` ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(RepairTaskService.formatRepairReportResult(result))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.reportResult === `${result}` ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.reportResult === `${result}` ? this.getRepairResultTone(result) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.reportResult === `${result}` ? this.getRepairResultTone(result) : AppColors.Border
    })
    .enabled(this.canSubmitRepairReport())
    .onClick(() => {
      this.reportResult = `${result}`;
      this.reportMessage = '';
      this.reportMessageTone = AppColors.Danger;
    })
  }

  @Builder
  RepairedAtField() {
    Column({ space: 10 }) {
      this.FieldTitle('维修时间')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(this.repairedAt.length > 0 ? this.repairedAt : '请选择维修时间')
          .fontSize(16)
          .fontColor(this.repairedAt.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
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
        if (!this.canSubmitRepairReport()) {
          return;
        }

        this.showRepairedAtPicker();
        this.reportMessage = '';
        this.reportMessageTone = AppColors.Danger;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProcessDescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('维修说明')

      TextArea({
        placeholder: '请输入维修说明',
        text: this.processDescription
      })
        .height(132)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(1000)
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
        .enabled(this.canSubmitRepairReport())
        .onChange((value: string) => {
          this.processDescription = value;
          this.reportMessage = '';
          this.reportMessageTone = AppColors.Danger;
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
        .enabled(this.canSubmitRepairReport())
        .onChange((value: string) => {
          if (!this.canSubmitRepairReport()) {
            return;
          }

          this.password = value;
          this.reportMessage = '';
          this.reportMessageTone = AppColors.Danger;
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
  ReportMessageText() {
    if (this.reportMessage.length > 0) {
      InlineMessageSurface({
        message: this.reportMessage,
        tone: this.reportMessageTone
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
    const response = await RepairTaskService.queryRepairTasksRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.taskMessage = UiFeedbackService.operationError(error, '刷新');
      this.taskMessageTone = AppColors.Danger;
      return;
    }

    const data = response.data;
    this.allTaskItems = data ? data.items : [];
    this.taskItems = [...this.allTaskItems];
    this.ensureSelectedTaskStillAvailable();
    this.taskMessage = UiFeedbackService.operationSuccess('刷新');
    this.taskMessageTone = AppColors.Success;
  }

  async submitRepairReport(): Promise<void> {
    if (this.submitting || this.isSelectedRepairTaskSubmitted()) {
      return;
    }

    const form = this.createRepairReportForm();
    const validation = RepairTaskService.validateRepairReportForm(form);
    if (!validation.valid) {
      this.reportMessage = validation.message;
      this.reportMessageTone = AppColors.Danger;
      return;
    }

    if (this.password.length === 0) {
      this.reportMessage = UiFeedbackService.requiredInput('密码');
      this.reportMessageTone = AppColors.Danger;
      return;
    }

    this.submitting = true;
    try {
      const verified = await this.verifyPasswordForSubmit(this.password);
      if (!verified) {
        return;
      }

      const response = await RepairTaskService.submitRepairReportRemoteFirst(form);
      if (!response.success) {
        const error = response.error;
        this.reportMessage = UiFeedbackService.operationError(error, '提交');
        this.reportMessageTone = AppColors.Danger;
        return;
      }

      this.reportMessage = UiFeedbackService.operationSuccess('提交');
      this.reportMessageTone = AppColors.Success;
      this.submittedRepairTaskId = this.normalizedTaskId;
      this.allTaskItems = this.allTaskItems.filter((item: RepairTaskItem) => {
        return item.taskNo !== this.normalizedTaskId && item.id !== this.normalizedTaskId;
      });
      this.taskItems = [...this.allTaskItems];
      this.clearSelectedTask();
      this.refreshTasks();
    } finally {
      this.submitting = false;
    }
  }

  createRepairReportForm(): RepairReportForm {
    return {
      taskId: this.taskId,
      result: this.reportResult as RepairReportResult,
      repairedAt: this.repairedAt,
      processDescription: this.processDescription,
      partsUsed: ''
    };
  }

  async verifyPasswordForSubmit(password: string): Promise<boolean> {
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(password);
    if (response.success && response.data === true) {
      return true;
    }

    this.reportMessage = UiFeedbackService.passwordVerificationError(response.error, '提交');
    this.reportMessageTone = AppColors.Danger;
    return false;
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.isSelectedRepairTaskSubmitted()) {
      return '已提交';
    }

    return '提交报告';
  }

  getSubmitIcon(): Resource {
    return $r('sys.symbol.checkmark_circle');
  }

  canSubmitRepairReport(): boolean {
    return !this.submitting && this.taskId.length > 0 && !this.isSelectedRepairTaskSubmitted();
  }

  isSelectedRepairTaskSubmitted(): boolean {
    return this.submittedRepairTaskId.length > 0 && this.normalizedTaskId === this.submittedRepairTaskId;
  }

  isTaskSelected(item: RepairTaskItem): boolean {
    const selectedTaskId = this.normalizedTaskId.trim();
    if (selectedTaskId.length === 0 || selectedTaskId === '-') {
      return false;
    }

    return item.taskNo === selectedTaskId || item.id === selectedTaskId;
  }

  selectTask(item: RepairTaskItem): void {
    this.taskId = item.id;
    this.normalizedTaskId = item.id;
    if (this.normalizedTaskId !== this.submittedRepairTaskId) {
      this.submittedRepairTaskId = '';
    }
    this.reportMessage = '';
    this.reportMessageTone = AppColors.Danger;
  }

  clearSelectedTask(): void {
    this.taskId = '';
    this.normalizedTaskId = '-';
    this.reportResult = '';
    this.repairedAt = '';
    this.processDescription = '';
    this.password = '';
  }

  ensureSelectedTaskStillAvailable(): void {
    if (this.taskId.length === 0) {
      return;
    }

    const exists = this.taskItems.some((item: RepairTaskItem) => {
      return item.id === this.taskId || item.taskNo === this.taskId;
    });
    if (!exists) {
      this.clearSelectedTask();
    }
  }

  getRepairResultTone(result: RepairReportResult): string {
    switch (result) {
      case RepairReportResult.Repaired:
        return AppColors.Success;
      case RepairReportResult.TemporaryRestored:
        return AppColors.Warning;
      case RepairReportResult.Unresolved:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  getSeverityTone(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return AppColors.Danger;
      case FaultSeverity.Severe:
        return AppColors.Warning;
      case FaultSeverity.General:
        return AppColors.Primary;
      case FaultSeverity.Minor:
        return AppColors.Success;
      default:
        return AppColors.TextSecondary;
    }
  }

  showRepairedAtPicker(): void {
    if (!this.canSubmitRepairReport()) {
      return;
    }

    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1, 0, 0),
      end: new Date(2100, 11, 31, 23, 59),
      selected: this.resolveSelectedDate(this.repairedAt),
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (value: Date) => {
        this.repairedAt = this.formatDateTime(value);
        this.reportMessage = '';
        this.reportMessageTone = AppColors.Danger;
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
    if (!MainPageNavigator.backOrReplace(this.getUIContext(), 'pages/OperationsCenter/OperationsCenter')) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: UiFeedbackService.operationUnavailable('页面跳转') });
      } catch (toastErr) {
      }
    }
  }
}
