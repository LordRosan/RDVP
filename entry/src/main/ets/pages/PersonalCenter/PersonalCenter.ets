import { AppColors } from '../../styles/AppTheme';
import { CurrentUserSnapshot } from '../../models/SessionModels';
import { SessionStore } from '../../stores/SessionStore';
import { HeaderCircleButton } from '../../components/HeaderCircleButton';

@Entry
@Component
struct PersonalCenter {
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State logoutActionMessage: string = '';
  @State logoutActionMessageTone: string = AppColors.Danger;
  @State settingsMessage: string = '';
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.currentUser = SessionStore.getCurrentUser();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.ProfilePanel()
          this.SessionPanel()
          this.ActionPanel()
        }
        .alignItems(HorizontalAlign.Start)
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
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
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
        this.backToWorkbench();
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
  SettingsButton() {
    HeaderCircleButton({
      icon: $r('sys.symbol.gearshape'),
      action: () => {
        this.openApplicationSettings();
      }
    })
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Column() {
        Text('个人中心')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.SettingsButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      bottom: 2
    })
  }

  @Builder
  ProfilePanel() {
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
          Text(this.currentUser.displayName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.currentUser.username ?? '-')
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

      this.InfoRow('用户权限', this.currentUser.roleName, AppColors.TextSecondary)
    }
    .padding(18)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SessionPanel() {
    Column({ space: 10 }) {
      Text('会话')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

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
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionPanel() {
    Column({ space: 12 }) {
      this.SettingsMessageText()
      this.LogoutActionMessageText()
      this.DangerButton('退出登录', $r('sys.symbol.person_badge_nosign'), () => {
        this.logout();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LogoutActionMessageText() {
    if (this.logoutActionMessage.length > 0) {
      Text(this.logoutActionMessage)
        .fontSize(13)
        .fontColor(this.logoutActionMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  SettingsMessageText() {
    if (this.settingsMessage.length > 0) {
      Text(this.settingsMessage)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
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
    .padding({
      left: 0,
      right: 0
    })
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
    .backgroundColor(AppColors.Surface)
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

  backToWorkbench(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/Workbench' });
      } catch (innerErr) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
        } catch (toastErr) {
        }
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
