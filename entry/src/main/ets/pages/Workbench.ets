import { AppColors, AppSpacing } from '../styles/AppTheme';
import { ActionTile } from '../components/ActionTile';
import { AppSectionTitle } from '../components/AppSectionTitle';
import { HeroSurface } from '../components/HeroSurface';
import { InlineMessageSurface } from '../components/InlineMessageSurface';
import { WorkbenchAction, WorkbenchActionId } from '../models/app/WorkbenchModels';
import { CurrentUserSnapshot } from '../models/identity/SessionModels';
import { WorkbenchService } from '../services/app/WorkbenchService';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Workbench {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: WorkbenchAction[] = WorkbenchService.getActions();
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State actionMessage: string = '';
  @State actionMessageTargetId: string = '';
  @State personalCenterMessage: string = '';
  @State currentTabIndex: number = 0;
  @State logoutActionMessage: string = '';
  @State settingsMessage: string = '';
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.refreshWorkbenchState();
  }

  onPageShow(): void {
    if (SessionStore.isAuthenticated()) {
      this.refreshWorkbenchState();
    }
  }

  refreshWorkbenchState(): void {
    this.applyWorkbenchState();
    WorkbenchService.refreshSummaryRemoteFirst().then(() => {
      this.applyWorkbenchState();
    }).catch(() => {
    });
  }

  applyWorkbenchState(): void {
    this.actions = WorkbenchService.getActions();
    this.currentUser = SessionStore.getCurrentUser();
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentTabIndex
    }) {
      TabContent() {
        this.HomeTab()
      }
      .tabBar(this.TabBarItem('首页', $r('sys.symbol.square_grid_2x2'), 0))

      TabContent() {
        this.ProfileTab()
      }
      .tabBar(this.TabBarItem('我的', $r('sys.symbol.person_crop_circle_fill'), 1))
    }
    .barMode(BarMode.Fixed)
    .barHeight(78)
    .scrollable(false)
    .onChange((index: number) => {
      this.currentTabIndex = index;
      this.clearInlineMessages();
      this.applyWorkbenchState();
    })
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  HomeTab() {
    Scroll() {
      Column({ space: AppSpacing.Section }) {
        this.Header()
        this.ActionSection()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: AppSpacing.PageX,
        right: AppSpacing.PageX,
        top: 18,
        bottom: 26
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  Header() {
    Column({ space: 12 }) {
      HeroSurface({
        eyebrow: this.getUserEyebrow(),
        title: 'RDVP 工作台',
        subtitle: this.getPermissionSummaryText(),
        icon: $r('sys.symbol.square_grid_2x2'),
        tone: AppColors.Primary
      })

      this.PersonalCenterMessageText()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '业务中心',
        subtitle: ''
      })

      Grid() {
        ForEach(this.actions, (item: WorkbenchAction) => {
          GridItem() {
            Column({ space: 8 }) {
              if (this.actionMessageTargetId === `${item.id}` && this.actionMessage.length > 0) {
                InlineMessageSurface({
                  message: this.actionMessage,
                  tone: AppColors.Danger
                })
              }

              ActionTile({
                action: item
              })
                .onClick(() => {
                  this.openCenter(item);
                })
            }
            .width('100%')
          }
        }, (item: WorkbenchAction) => item.id)
      }
      .columnsTemplate('1fr')
      .rowsGap(10)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  PersonalCenterMessageText() {
    if (this.personalCenterMessage.length > 0) {
      InlineMessageSurface({
        message: this.personalCenterMessage,
        tone: AppColors.Danger
      })
    }
  }

  getUserEyebrow(): string {
    if (this.currentUser.roleName.length > 0) {
      return `${this.currentUser.roleName} 的业务入口`;
    }

    return '业务入口';
  }

  @Builder
  ProfileTab() {
    Scroll() {
      Column({ space: AppSpacing.Section }) {
        this.ProfileHeader()
        this.ProfilePanel()
        this.SessionPanel()
        this.ProfileActionPanel()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: AppSpacing.PageX,
        right: AppSpacing.PageX,
        top: 18,
        bottom: 26
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  ProfileHeader() {
    HeroSurface({
      eyebrow: this.getProfileEyebrow(),
      title: '我的',
      subtitle: this.getProfileSubtitle(),
      icon: $r('sys.symbol.person_crop_circle_fill'),
      tone: AppColors.Primary
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
          Text(this.getDisplayName())
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

      this.InfoRow('用户权限', this.getRoleName(), AppColors.TextSecondary)
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
      AppSectionTitle({
        title: '会话',
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
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProfileActionPanel() {
    Column({ space: 12 }) {
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
        tone: AppColors.Danger
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

  getPermissionSummaryText(): string {
    const count = this.actions.length;
    if (count <= 0) {
      return '当前账号暂无可访问中心';
    }

    return `当前账号可访问 ${count} 个中心`;
  }

  openPersonalCenter(): void {
    this.currentTabIndex = 1;
    this.clearInlineMessages();
  }

  openCenter(action: WorkbenchAction): void {
    this.actionMessage = '';
    this.actionMessageTargetId = '';
    this.personalCenterMessage = '';

    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    if (action.id === WorkbenchActionId.ArchiveCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/ArchiveCenter' });
      } catch (err) {
        this.actionMessage = '档案中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === WorkbenchActionId.OperationsCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/OperationsCenter/OperationsCenter' });
      } catch (err) {
        this.actionMessage = '运维中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === WorkbenchActionId.ManagementCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ManagementCenter/ManagementCenter' });
      } catch (err) {
        this.actionMessage = '管理中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    this.actionMessage = '中心入口暂不可用';
    this.actionMessageTargetId = `${action.id}`;
  }

  @Builder
  TabBarItem(label: string, icon: Resource, index: number) {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([this.currentTabIndex === index ? AppColors.Primary : AppColors.TextTertiary])

      Text(label)
        .fontSize(12)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? AppColors.Primary : AppColors.TextSecondary)
        .maxLines(1)
    }
    .width('100%')
    .height(62)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  clearInlineMessages(): void {
    this.personalCenterMessage = '';
    this.actionMessage = '';
    this.actionMessageTargetId = '';
    this.settingsMessage = '';
    this.logoutActionMessage = '';
  }

  getProfileEyebrow(): string {
    if (this.currentUser.roleName.length > 0) {
      return this.currentUser.roleName;
    }

    return '个人中心';
  }

  getProfileSubtitle(): string {
    const username = this.currentUser.username === undefined ? '' : this.currentUser.username;
    if (username.length > 0) {
      return `账号 ${username}`;
    }

    return '账号信息与会话管理';
  }

  getDisplayName(): string {
    if (this.currentUser.displayName.length > 0) {
      return this.currentUser.displayName;
    }

    if (this.currentUser.username !== undefined && this.currentUser.username.length > 0) {
      return this.currentUser.username;
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
        return;
      }

      this.actionMessage = '登录页不可用';
      this.actionMessageTargetId = `${WorkbenchActionId.ArchiveCenter}`;
    }
  }
}
