import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import {
  DeviceArchiveChangeBaseline,
  DeviceArchiveChangeDraft,
  DeviceArchiveChangeRequestForm,
  DeviceArchiveChangeRequestStatus
} from '../../models/DeviceArchiveChangeModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceArchiveChangeService } from '../../services/DeviceArchiveChangeService';
import { DeviceService } from '../../services/DeviceService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const DEVICE_CHANGE_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '变更申请',
    items: [
      {
        label: '提交申请',
        description: '填写需要修正的设备档案字段和变更原因，形成待审核申请'
      },
      {
        label: '审核生效',
        description: '申请通过管理员审核后才会写入正式设备档案，避免误改和越权修改'
      }
    ]
  },
  {
    title: '变更内容',
    items: [
      {
        label: '设备名称',
        description: '用于识别设备业务含义，名称应清晰、稳定，避免临时描述'
      },
      {
        label: '设备型号',
        description: '记录设备规格或版本信息，便于后续维修、备件和兼容性判断'
      },
      {
        label: '生产厂商',
        description: '记录设备来源方或制造方，便于追溯质量、保修和技术支持责任'
      },
      {
        label: '设备位置',
        description: '记录设备当前部署位置，应能支持现场定位和运维派发'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveChange {
  @State deviceCode: string = '';
  @State deviceName: string = '';
  @State model: string = '';
  @State manufacturer: string = '';
  @State locationAddress: string = '';
  @State reason: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State normalizedDeviceCode: string = '-';
  @State changeCount: number = 0;
  @State requestStatus: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.Draft;
  @State hasDevice: boolean = false;
  @State submitting: boolean = false;
  private currentDeviceId: string = '';
  private baseline?: DeviceArchiveChangeBaseline = undefined;
  private changeInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '设备档案变更说明',
      sections: DEVICE_CHANGE_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveChangeRequestCreate)) {
      return;
    }

    this.loadArchiveContext();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.ChangeForm()
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
    this.backToDetail();
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
        this.backToDetail();
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
      Row({ space: 6 }) {
        Text('设备档案变更')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showChangeInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('提交设备档案修改申请')
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
  ChangeForm() {
    Column({ space: 16 }) {
      this.DeviceCodeField()
      this.DeviceNameField()
      this.DeviceModelField()
      this.ManufacturerField()
      this.LocationAddressField()
      this.ReasonField()
      this.MessageText()
      this.ActionButton(this.getSubmitButtonLabel(), $r('sys.symbol.checkmark_circle'),
        this.hasDevice && !this.submitting && !this.isChangeSubmitted(), () => {
          this.submitChangeRequest();
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
  DeviceCodeField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备编号')

      TextInput({
        placeholder: '设备编号',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .fontColor(AppColors.TextSecondary)
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .enabled(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceNameField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备名称')

      if (this.isChangeSubmitted()) {
        Text(this.deviceName)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的设备名称',
          text: this.deviceName
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.deviceName = value;
            this.message = '';
            this.updateChangeCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceModelField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备型号')

      if (this.isChangeSubmitted()) {
        Text(this.model)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的设备型号',
          text: this.model
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.model = value;
            this.message = '';
            this.updateChangeCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ManufacturerField() {
    Column({ space: 10 }) {
      this.FieldTitle('生产厂商')

      if (this.isChangeSubmitted()) {
        Text(this.manufacturer)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的生产厂商',
          text: this.manufacturer
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.manufacturer = value;
            this.message = '';
            this.updateChangeCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LocationAddressField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备位置')

      if (this.isChangeSubmitted()) {
        Text(this.locationAddress)
          .height(56)
          .width('100%')
          .fontSize(16)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
      } else {
        TextInput({
          placeholder: '填写新的设备位置',
          text: this.locationAddress
        })
          .height(56)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .onChange((value: string) => {
            this.locationAddress = value;
            this.message = '';
            this.updateChangeCount();
            this.saveDraft();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('变更原因')

      TextArea({
        placeholder: '填写变更依据、现场情况或补充说明',
        text: this.reason
      })
        .height(118)
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
        .border({
          width: 1,
          color: AppColors.Border
        })
        .enabled(!this.isChangeSubmitted())
        .onChange((value: string) => {
          this.reason = value;
          this.message = '';
          this.saveDraft();
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
          .fontColor([AppColors.Surface])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.Surface)
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
  InfoButton(action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor([AppColors.TextPrimary])
    }
    .width(28)
    .height(28)
    .backgroundColor(AppColors.Transparent)
    .onClick(() => {
      action();
    })
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('提交状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '标准编号', value: this.normalizedDeviceCode, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '变更字段', value: `${this.changeCount}项`, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '申请状态',
          value: DeviceArchiveChangeService.formatRequestStatus(this.requestStatus),
          tone: this.getStatusTone(this.requestStatus)
        })
        this.CardDivider()
        StatusInfoRow({
          label: '服务状态',
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
      })
  }

  async submitChangeRequest(): Promise<void> {
    if (this.submitting) {
      return;
    }

    const form = this.buildForm();
    const validation = DeviceArchiveChangeService.validateChangeRequestForm(form);
    this.normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(this.deviceCode);
    this.changeCount = validation.changeCount !== undefined ?
      validation.changeCount : DeviceArchiveChangeService.countChangedFields(form);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!validation.valid) {
      this.message = validation.message;
      this.messageTone = AppColors.Danger;
      return;
    }

    this.submitting = true;
    const response = await DeviceArchiveChangeService.submitChangeRequestRemoteFirst(form);
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '变更申请提交失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    const submittedDraft = this.buildDraft();
    this.requestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
    DeviceArchiveFlowStore.markChangePending(response.data ? response.data.id : '', submittedDraft);
    this.applyDraft(submittedDraft);
    this.changeCount = DeviceArchiveChangeService.countChangedFields(this.buildForm());
    this.message = '变更申请已提交，等待管理员审核';
    this.messageTone = AppColors.Success;
  }

  buildForm(): DeviceArchiveChangeRequestForm {
    return {
      deviceId: this.currentDeviceId,
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason,
      baseline: this.baseline
    };
  }

  updateChangeCount(): void {
    this.changeCount = DeviceArchiveChangeService.countChangedFields(this.buildForm());
    if (!this.isChangeSubmitted()) {
      this.requestStatus = DeviceArchiveChangeRequestStatus.Draft;
    }
  }

  getStatusTone(status: DeviceArchiveChangeRequestStatus): string {
    switch (status) {
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return AppColors.Warning;
      case DeviceArchiveChangeRequestStatus.Approved:
        return AppColors.Success;
      case DeviceArchiveChangeRequestStatus.Rejected:
        return AppColors.Danger;
      case DeviceArchiveChangeRequestStatus.Draft:
      default:
        return AppColors.TextSecondary;
    }
  }

  isChangeSubmitted(): boolean {
    return this.requestStatus === DeviceArchiveChangeRequestStatus.PendingReview;
  }

  getSubmitButtonLabel(): string {
    if (this.submitting) {
      return '提交中';
    }

    if (this.isChangeSubmitted()) {
      return '已提交';
    }

    return '提交申请';
  }

  showChangeInfoDialog(): void {
    this.changeInfoDialogController.open();
  }

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      this.hasDevice = false;
      this.message = '未获取设备档案，请返回后重新查询';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.hasDevice = true;
    this.currentDeviceId = device.id;
    this.baseline = {
      deviceName: device.name,
      model: device.model,
      manufacturer: device.manufacturer,
      locationAddress: device.location.address
    };

    const pendingDraft = DeviceArchiveFlowStore.getPendingDraft();
    if (pendingDraft !== undefined && pendingDraft.deviceCode === device.deviceCode) {
      this.applyDraft(pendingDraft);
      this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
      this.changeCount = DeviceArchiveChangeService.countChangedFields(this.buildForm());
      this.requestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
      this.message = '变更申请已提交，等待管理员审核';
      this.messageTone = AppColors.Success;
      return;
    }

    const draft = DeviceArchiveFlowStore.getDraft();
    if (draft !== undefined && draft.deviceCode === device.deviceCode) {
      this.applyDraft(draft);
    } else {
      this.deviceCode = device.deviceCode;
      this.deviceName = device.name;
      this.model = device.model;
      this.manufacturer = device.manufacturer;
      this.locationAddress = device.location.address;
      this.reason = '';
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    this.updateChangeCount();
  }

  applyDraft(draft: DeviceArchiveChangeDraft): void {
    this.deviceCode = draft.deviceCode;
    this.deviceName = draft.deviceName;
    this.model = draft.model;
    this.manufacturer = draft.manufacturer;
    this.locationAddress = draft.locationAddress;
    this.reason = draft.reason;
  }

  saveDraft(): void {
    if (!this.hasDevice) {
      return;
    }

    DeviceArchiveFlowStore.saveDraft(this.buildDraft());
  }

  buildDraft(): DeviceArchiveChangeDraft {
    return {
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason
    };
  }

  backToDetail(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveDetail' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
