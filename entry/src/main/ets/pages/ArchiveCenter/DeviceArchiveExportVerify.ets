import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { AuthService } from '../../services/identity/AuthService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

@Entry
@Component
struct DeviceArchiveExportVerify {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State password: string = '';
  @State message: string = '';
  @State verifying: boolean = false;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveExport)) {
      return;
    }

    if (DeviceArchiveFlowStore.getCurrentDevice() === undefined) {
      this.message = '未获取设备档案，请重新查询';
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.ModeHeader()
          this.VerifyForm()
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
      .backgroundColor(AppColors.SurfaceRaised)
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToDetail();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: AppSpacing.PageX,
      right: AppSpacing.PageX
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('身份核验')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Identity Verification')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: 6
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerifyForm() {
    Column({ space: 16 }) {
      this.PasswordField()
      this.MessageText()
      this.VerifySubmitButton(() => {
        this.verifyPassword();
      })
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
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PasswordField() {
    Column({ space: 10 }) {
      Text('密码')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

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
        .enabled(!this.verifying)
        .onChange((value: string) => {
          if (this.verifying) {
            return;
          }

          this.password = value;
          this.message = '';
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  VerifySubmitButton(action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.verifying }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.verifying ? '核验中' : '核验')
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
    .backgroundColor(this.verifying ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.verifying)
    .onClick(() => {
      action();
    })
  }

  async verifyPassword(): Promise<void> {
    if (this.verifying) {
      return;
    }

    if (this.password.length === 0) {
      this.message = '请输入密码';
      return;
    }

    if (DeviceArchiveFlowStore.getCurrentDevice() === undefined) {
      this.message = '未获取设备档案，请重新查询';
      return;
    }

    this.verifying = true;
    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(this.password);
    this.verifying = false;

    if (!response.success || response.data !== true) {
      const errorCode = response.error === undefined ? '' : `${response.error.code}`;
      this.message = this.mapVerifyErrorMessage(errorCode);
      return;
    }

    this.password = '';
    this.message = '';
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveExport' });
    } catch (err) {
      this.message = '导出功能暂不可用，请稍后重试';
    }
  }

  mapVerifyErrorMessage(errorCode: string): string {
    if (errorCode === 'INVALID_CREDENTIALS' || errorCode === 'LOGIN_FAILED' || errorCode === 'UNAUTHORIZED') {
      return '密码不正确，请重新输入';
    }

    if (errorCode === 'PASSWORD_REQUIRED') {
      return '请输入密码';
    }

    return '导出功能暂不可用，请稍后重试';
  }

  backToDetail(): void {
    if (!MainPageNavigator.backOrReplace(this.getUIContext(), 'pages/ArchiveCenter/DeviceArchiveDetail')) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
