import { AppColors, AppRadii, AppSpacing } from '../styles/AppTheme';
import { AuthService } from '../services/identity/AuthService';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State submitting: boolean = false;
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;

  aboutToAppear(): void {
    if (SessionStore.isAuthenticated()) {
      this.openMainPage();
      return;
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.BrandHeader()
        this.LoginPanel()
      }
      .width('100%')
      .padding({
        left: AppSpacing.PageX,
        right: AppSpacing.PageX,
        top: 30,
        bottom: AppSpacing.PageBottom
      })
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    return true;
  }

  @Builder
  BrandHeader() {
    Column({ space: 6 }) {
      Text('RDVP')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('Remote Device Verification Program')
        .fontSize(14)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 12,
      bottom: 6
    })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  LoginPanel() {
    Column({ space: 20 }) {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.person_badge_checkmark'))
          .fontSize(44)
          .fontColor([AppColors.Primary])

        Text('登录')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      this.InputField('账号', '请输入账号', false)
      this.InputField('密码', '请输入密码', true)
      this.MessageText()
      this.LoginButton()
    }
    .padding({
      left: 20,
      right: 20,
      top: 22,
      bottom: 22
    })
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InputField(label: string, placeholder: string, secure: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      TextInput({
        placeholder,
        text: secure ? this.password : this.username
      })
        .type(secure ? InputType.Password : InputType.Normal)
        .height(54)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(AppRadii.Medium)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .onChange((value: string) => {
          if (secure) {
            this.password = value;
          } else {
            this.username = value;
          }
          this.message = '';
          this.messageTone = AppColors.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  LoginButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.person_badge_checkmark'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.submitting ? '登录中' : '登录')
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
    .backgroundColor(this.submitting ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.submitting)
    .onClick(() => {
      this.submitLogin();
    })
  }

  async submitLogin(): Promise<void> {
    if (this.submitting) {
      return;
    }

    this.submitting = true;
    const validationMessage = this.validateBeforeRemoteLogin();
    if (validationMessage.length > 0) {
      this.message = validationMessage;
      this.messageTone = AppColors.Danger;
      this.submitting = false;
      return;
    }

    const response = await AuthService.loginRemoteFirst({
      username: this.username,
      password: this.password
    });
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = this.normalizeLoginErrorMessage(error === undefined ? '' : `${error.code}`, error === undefined ? '' : error.message);
      this.messageTone = AppColors.Danger;
      return;
    }

    if (response.data !== undefined) {
      SessionStore.setSession(response.data);
    }

    this.openMainPage();
  }

  validateBeforeRemoteLogin(): string {
    const usernameEmpty = this.username.trim().length === 0;
    const passwordEmpty = this.password.length === 0;
    if (usernameEmpty && passwordEmpty) {
      return '请输入账号和密码';
    }

    if (usernameEmpty) {
      return '请输入账号';
    }

    if (passwordEmpty) {
      return '请输入密码';
    }

    return '';
  }

  normalizeLoginErrorMessage(errorCode: string, fallbackMessage: string): string {
    if (errorCode === 'UNAUTHORIZED' || errorCode === 'INVALID_CREDENTIALS' || errorCode === 'LOGIN_FAILED') {
      return '账号或密码不正确，请重新输入';
    }

    return fallbackMessage.length > 0 ? fallbackMessage : '登录失败';
  }

  openMainPage(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
