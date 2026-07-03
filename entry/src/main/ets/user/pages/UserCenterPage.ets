import { AppColors, AppRadii, AppSpacing, AppTone } from '../../shared/theme/AppTheme';
import { AccountActionTile } from '../../shared/components/AccountActionTile';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { CurrentUserSnapshot } from '../models/SessionModels';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { SessionStore } from '../stores/SessionStore';
import { AppRoutes } from '../../shared/navigation/AppRoutes';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';

@Entry
@Component
struct UserCenterPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State logoutActionMessage: string = '';
  @State logoutActionMessageTone: string = UiFeedbackTone.Danger;
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
    this.backToHomePage();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToHomePage();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text('用户中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('User Center')
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
              .fontSize(24)
              .fontColor([AppColors.Primary])
          }
          .width(48)
          .height(48)
          .borderRadius(18)
          .backgroundColor(AppColors.PrimarySurface)

          Column({ space: 5 }) {
            Text(this.getDisplayName())
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.getRoleName())
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
        this.InfoRow('有效期至', this.formatSessionExpiresAt(), AppColors.TextSecondary)
        this.InfoRow('登录状态', SessionStore.isAuthenticated() ? '已登录' : '未登录',
          SessionStore.isAuthenticated() ? AppColors.Success : AppColors.Danger)
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
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '账户操作',
        subtitle: ''
      })

      this.SettingsMessageText()
      this.LogoutActionMessageText()
      Column({ space: 10 }) {
        AccountActionTile({
          label: '应用设置',
          icon: $r('sys.symbol.gearshape'),
          tone: AppTone.Primary
        })
          .onClick(() => {
            this.openUserSettings();
          })

        AccountActionTile({
          label: '退出登录',
          icon: $r('sys.symbol.person_badge_nosign'),
          tone: AppTone.Danger
        })
          .onClick(() => {
            this.logout();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SettingsMessageText() {
    if (this.settingsMessage.length > 0) {
      InlineMessageSurface({
        message: this.settingsMessage,
        tone: UiFeedbackTone.Danger
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

  refreshSessionState(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.currentUser = SessionStore.getCurrentUser();
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

  backToHomePage(): void {
    AppNavigator.replaceToHomePage(this.getUIContext(), () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }

  logout(): void {
    SessionStore.clearSession();
    this.openLoginPage('logout');
  }

  openUserSettings(): void {
    this.settingsMessage = '';
    AppNavigator.push(this.getUIContext(), AppRoutes.UserSettingsPage, () => {
      this.settingsMessage = UiFeedbackService.operationUnavailable('应用设置');
    });
  }

  openLoginPage(source: string = ''): void {
    AppNavigator.replace(this.getUIContext(), AppRoutes.LoginPage, () => {
      if (source === 'logout') {
        this.logoutActionMessage = UiFeedbackService.operationUnavailable('页面跳转');
        this.logoutActionMessageTone = UiFeedbackTone.Danger;
        return;
      }

      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }
}
