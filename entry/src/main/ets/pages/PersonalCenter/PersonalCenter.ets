import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { HeroSurface } from '../../components/HeroSurface';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { CurrentUserSnapshot } from '../../models/identity/SessionModels';
import { SessionStore } from '../../stores/SessionStore';
import { MainPageNavigator } from '../../utils/MainPageNavigator';

@Entry
@Component
struct PersonalCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State logoutActionMessage: string = '';
  @State logoutActionMessageTone: string = AppColors.Danger;
  @State settingsMessage: string = '';

  aboutToAppear(): void {
    this.refreshSessionState();
  }

  onPageShow(): void {
    this.refreshSessionState();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.Header()
          this.ProfileSection()
          this.SessionSection()
          this.ActionSection()
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
    this.backToMainPage();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToMainPage();
      }
    })
  }

  @Builder
  Header() {
    HeroSurface({
      eyebrow: this.getProfileEyebrow(),
      title: '个人中心',
      subtitle: this.getProfileSubtitle(),
      icon: $r('sys.symbol.person_crop_circle_fill'),
      tone: AppColors.Primary
    })
  }

  @Builder
  ProfileSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '账号信息',
        subtitle: ''
      })

      Column({ space: 16 }) {
        Row({ space: 14 }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.person_fill'))
              .fontSize(38)
              .fontColor([AppColors.OnPrimary])
          }
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor(AppColors.Primary)

          Column({ space: 5 }) {
            Text(this.getDisplayName())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.getUsername())
              .fontSize(14)
              .fontColor(AppColors.TextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Divider()
          .height(1)
          .backgroundColor(AppColors.Divider)

        this.InfoRow('账号', this.getUsername(), AppColors.TextSecondary)
        this.InfoRow('用户权限', this.getRoleName(), AppColors.TextSecondary)
      }
      .padding(18)
      .width('100%')
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
  SessionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '会话状态',
        subtitle: ''
      })

      Column() {
        this.InfoRow('有效期至', this.formatSessionExpiresAt(), AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('登录状态', SessionStore.isAuthenticated() ? '已登录' : '未登录',
          SessionStore.isAuthenticated() ? AppColors.Success : AppColors.Danger)
      }
      .width('100%')
      .padding({
        left: 18,
        right: 18
      })
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '账户操作',
        subtitle: ''
      })

      this.SettingsMessageText()
      this.LogoutActionMessageText()
      this.SecondaryButton('应用设置', $r('sys.symbol.gearshape'), () => {
        this.openApplicationSettings();
      })
      this.DangerButton('退出登录', $r('sys.symbol.person_badge_nosign'), () => {
        this.logout();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SettingsMessageText() {
    if (this.settingsMessage.length > 0) {
      InlineMessageSurface({
        message: this.settingsMessage,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  LogoutActionMessageText() {
    if (this.logoutActionMessage.length > 0) {
      InlineMessageSurface({
        message: this.logoutActionMessage,
        tone: this.logoutActionMessageTone
      })
    }
  }

  @Builder
  InfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(15)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(54)
    .width('100%')
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
  }

  @Builder
  SecondaryButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(label)
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
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .border({
      width: 1,
      color: AppColors.Border
    })
    .onClick(() => {
      action();
    })
  }

  @Builder
  DangerButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
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
    .backgroundColor(AppColors.Danger)
    .onClick(() => {
      action();
    })
  }

  refreshSessionState(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.currentUser = SessionStore.getCurrentUser();
  }

  getProfileEyebrow(): string {
    const roleName = this.getRoleName();
    return roleName.length > 0 && roleName !== '-' ? roleName : '个人中心';
  }

  getProfileSubtitle(): string {
    const username = this.getUsername();
    if (username.length > 0 && username !== '-') {
      return `账号 ${username}`;
    }

    return '账号信息与会话管理';
  }

  getDisplayName(): string {
    if (this.currentUser.displayName.length > 0) {
      return this.currentUser.displayName;
    }

    const username = this.currentUser.username;
    if (username !== undefined && username.length > 0) {
      return username;
    }

    return '-';
  }

  getUsername(): string {
    const username = this.currentUser.username;
    if (username !== undefined && username.length > 0) {
      return username;
    }

    return '-';
  }

  getRoleName(): string {
    if (this.currentUser.roleName.length > 0) {
      return this.currentUser.roleName;
    }

    return '-';
  }

  formatSessionExpiresAt(): string {
    const expiresAt = this.currentUser.expiresAt;
    if (expiresAt === undefined || expiresAt.length === 0) {
      return '-';
    }

    const date = new Date(expiresAt);
    if (Number.isNaN(date.getTime())) {
      return expiresAt;
    }

    return `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())} ${this.pad2(
      date.getHours())}:${this.pad2(date.getMinutes())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  backToMainPage(): void {
    if (!MainPageNavigator.replaceToMainPage(this.getUIContext())) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }

  logout(): void {
    SessionStore.clearSession();
    this.openLoginPage('logout');
  }

  openApplicationSettings(): void {
    this.settingsMessage = '';
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/PersonalCenter/ApplicationSettings' });
    } catch (err) {
      this.settingsMessage = '应用设置不可用';
    }
  }

  openLoginPage(source: string = ''): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Login' });
    } catch (err) {
      if (source === 'logout') {
        this.logoutActionMessage = '页面跳转失败';
        this.logoutActionMessageTone = AppColors.Danger;
        return;
      }

      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
