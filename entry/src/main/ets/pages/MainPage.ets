import { AppColors, AppSpacing } from '../styles/AppTheme';
import { ActionTile } from '../components/ActionTile';
import { AppSectionTitle } from '../components/AppSectionTitle';
import { HeroSurface } from '../components/HeroSurface';
import { InlineMessageSurface } from '../components/InlineMessageSurface';
import { DashboardMetric, MainPageAction, MainPageActionId, MainPageDashboard } from '../models/app/MainPageModels';
import { CurrentUserSnapshot } from '../models/identity/SessionModels';
import { MainPageService } from '../services/app/MainPageService';
import { DashboardRefreshStore } from '../stores/DashboardRefreshStore';
import { MainPageViewportStore } from '../stores/MainPageViewportStore';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct MainPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @Watch('onDashboardRefreshRevisionChanged')
  @StorageLink(DashboardRefreshStore.StorageKey) dashboardRefreshRevision: number = 0;
  @State actions: MainPageAction[] = MainPageService.getActions();
  @State dashboard: MainPageDashboard = MainPageService.getEmptyDashboard();
  @State dashboardLoaded: boolean = false;
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State actionMessage: string = '';
  @State actionMessageTargetId: string = '';
  @State currentTabIndex: number = 0;
  @State logoutActionMessage: string = '';
  @State settingsMessage: string = '';
  @State dashboardRenderRevision: number = 0;
  private dashboardRequestVersion: number = 0;
  private homeScroller: Scroller = new Scroller();
  private homeScrollRestoreCount: number = 0;
  private readonly maxHomeScrollRestoreCount: number = 2;

  aboutToAppear(): void {
    DashboardRefreshStore.ensureInitialized();
    MainPageViewportStore.ensureInitialized();
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.refreshMainPageState();
  }

  onDashboardRefreshRevisionChanged(): void {
    if (SessionStore.isAuthenticated()) {
      this.refreshMainPageState();
    }
  }

  onPageShow(): void {
    if (SessionStore.isAuthenticated()) {
      this.refreshMainPageState();
    }
  }

  refreshMainPageState(): void {
    this.applyMainPageState();
    this.refreshDashboard();
  }

  applyMainPageState(): void {
    this.actions = MainPageService.getActions();
    this.currentUser = SessionStore.getCurrentUser();
  }

  async refreshDashboard(): Promise<void> {
    const refreshVersion = this.dashboardRequestVersion + 1;
    this.dashboardRequestVersion = refreshVersion;
    const response = await MainPageService.fetchDashboardRemoteFirst();
    if (refreshVersion !== this.dashboardRequestVersion) {
      return;
    }

    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    if (response.success && response.data !== undefined) {
      this.dashboard = response.data;
      this.dashboardLoaded = true;
      this.dashboardRenderRevision += 1;
      this.restoreHomeScrollPosition();
    }
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
      this.applyMainPageState();
    })
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  HomeTab() {
    Scroll(this.homeScroller) {
      Column({ space: AppSpacing.Section }) {
        this.Header()
        this.DashboardSection()
        this.ActionSection()
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .padding({
        left: AppSpacing.PageX,
        right: AppSpacing.PageX,
        top: 18,
        bottom: 26
      })
      .width('100%')
      .constraintSize({ minHeight: '100%' })
    }
    .height('100%')
    .width('100%')
    .onScrollStop(() => {
      this.saveHomeScrollPosition();
    })
    .onAppear(() => {
      this.restoreHomeScrollPosition();
    })
  }

  @Builder
  Header() {
    Column({ space: 14 }) {
      Column({ space: 5 }) {
        Text('RDVP')
          .fontSize(38)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)

        Text('Remote Device Verification Program')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text('欢迎您')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextTertiary)
            .maxLines(1)

          Text(this.getWelcomeName())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.getRoleName())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.Primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({
            left: 12,
            right: 12,
            top: 7,
            bottom: 7
          })
          .backgroundColor(AppColors.PrimarySurface)
          .borderRadius(18)
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 14,
        bottom: 14
      })
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .alignItems(VerticalAlign.Center)
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
  DashboardSection() {
    if (this.dashboardLoaded && this.hasDashboardContent()) {
      ForEach([this.dashboardRenderRevision], () => {
        this.DashboardContent()
      }, (revision: number) => `${revision}`)
    }
  }

  @Builder
  DashboardContent() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '数据看板',
        subtitle: ''
      })

      if (this.shouldShowArchiveDashboard()) {
        this.DashboardCenterCard(
          '档案中心',
          '档案数',
          this.getArchivePrimaryValue(),
          this.getArchiveDashboardMetrics(),
          $r('sys.symbol.text_clipboard'),
          AppColors.Primary)
      }

      if (this.shouldShowOperationsDashboard()) {
        this.DashboardCenterCard(
          '运维中心',
          '任务数',
          this.getOperationsPrimaryValue(),
          this.getOperationsDashboardMetrics(),
          $r('sys.symbol.wrench_and_screwdriver'),
          AppColors.Success)
      }

      if (this.shouldShowManagementDashboard()) {
        this.DashboardCenterCard(
          '管理中心',
          this.getManagementPrimaryLabel(),
          this.getManagementPrimaryValue(),
          this.getManagementDashboardMetrics(),
          $r('sys.symbol.checkmark_shield'),
          AppColors.Warning)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DashboardCenterCard(
    title: string,
    primaryLabel: string,
    primaryValue: number,
    metrics: DashboardMetric[],
    icon: Resource,
    tone: string
  ) {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph(icon)
            .fontSize(24)
            .fontColor([tone])
        }
        .width(46)
        .height(46)
        .borderRadius(16)
        .backgroundColor(this.getDashboardToneSurface(tone))

        Column({ space: 4 }) {
          Text(title)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(primaryLabel)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text(this.formatDashboardValue(primaryValue))
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(tone)
            .maxLines(1)
            .textAlign(TextAlign.End)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (metrics.length > 0) {
        Divider()
          .height(1)
          .backgroundColor(AppColors.Divider)

        Grid() {
          ForEach(metrics, (metric: DashboardMetric) => {
            GridItem() {
              this.DashboardMetricCell(metric)
            }
          }, (metric: DashboardMetric) => `${metric.label}-${metric.value}`)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(14)
        .rowsGap(14)
        .width('100%')
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(24)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  @Builder
  DashboardMetricCell(metric: DashboardMetric) {
    Column({ space: 4 }) {
      Text(this.formatDashboardValue(metric.value))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text(metric.label)
        .fontSize(12)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        ForEach(this.actions, (item: MainPageAction) => {
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
        }, (item: MainPageAction) => item.id)
      }
      .columnsTemplate('1fr')
      .rowsGap(10)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
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

  openCenter(action: MainPageAction): void {
    this.actionMessage = '';
    this.actionMessageTargetId = '';
    this.saveHomeScrollPosition();

    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    if (action.id === MainPageActionId.ArchiveCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/ArchiveCenter' });
      } catch (err) {
        this.actionMessage = '档案中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === MainPageActionId.OperationsCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/OperationsCenter/OperationsCenter' });
      } catch (err) {
        this.actionMessage = '运维中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === MainPageActionId.ManagementCenter) {
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
    this.actionMessage = '';
    this.actionMessageTargetId = '';
    this.settingsMessage = '';
    this.logoutActionMessage = '';
  }

  saveHomeScrollPosition(): void {
    try {
      const offset = this.homeScroller.currentOffset();
      MainPageViewportStore.setHomeScrollY(offset.yOffset);
    } catch (err) {
    }
  }

  restoreHomeScrollPosition(): void {
    if (this.homeScrollRestoreCount >= this.maxHomeScrollRestoreCount) {
      return;
    }

    const yOffset = MainPageViewportStore.getHomeScrollY();
    if (yOffset <= 0) {
      return;
    }

    this.homeScrollRestoreCount += 1;
    setTimeout(() => {
      try {
        this.homeScroller.scrollTo({
          xOffset: 0,
          yOffset: yOffset,
          animation: false
        });
      } catch (err) {
      }
    }, 0);
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

  getWelcomeName(): string {
    if (this.currentUser.username !== undefined && this.currentUser.username.length > 0) {
      return this.currentUser.username;
    }

    return this.getDisplayName();
  }

  getArchiveDashboardMetrics(): DashboardMetric[] {
    const archive = this.dashboard.archive;
    if (archive === undefined) {
      return [];
    }

    return [
      { label: '档案添加', value: archive.archiveCreates },
      { label: '档案删除', value: archive.archiveDeletes },
      { label: '档案修改', value: archive.archiveUpdates },
      { label: '档案查询', value: archive.archiveQueries },
      { label: '档案导出', value: archive.archiveExports }
    ];
  }

  getOperationsDashboardMetrics(): DashboardMetric[] {
    const operations = this.dashboard.operations;
    if (operations === undefined) {
      return [];
    }

    return [
      { label: '核验', value: operations.verifications },
      { label: '报修', value: operations.faultReports },
      { label: '维修', value: operations.repairs },
      { label: '复检', value: operations.reinspections }
    ];
  }

  getManagementDashboardMetrics(): DashboardMetric[] {
    const management = this.dashboard.management;
    if (management === undefined) {
      return [];
    }

    const primaryKey = this.getManagementPrimaryKey();
    const metrics: DashboardMetric[] = [];
    if (management.pendingArchiveReviews !== undefined && primaryKey !== 'pendingArchiveReviews') {
      metrics.push({ label: '待审核档案操作', value: management.pendingArchiveReviews });
    }
    if (management.pendingOperationsReviews !== undefined && primaryKey !== 'pendingOperationsReviews') {
      metrics.push({ label: '待审核运维操作', value: management.pendingOperationsReviews });
    }

    return metrics;
  }

  hasDashboardContent(): boolean {
    return this.shouldShowArchiveDashboard() ||
      this.shouldShowOperationsDashboard() ||
      this.shouldShowManagementDashboard();
  }

  shouldShowArchiveDashboard(): boolean {
    return this.dashboard.archive !== undefined;
  }

  shouldShowOperationsDashboard(): boolean {
    return this.dashboard.operations !== undefined;
  }

  shouldShowManagementDashboard(): boolean {
    const management = this.dashboard.management;
    return management !== undefined &&
      (management.reviewedTotal !== undefined ||
        management.pendingArchiveReviews !== undefined ||
        management.pendingOperationsReviews !== undefined);
  }

  getArchivePrimaryValue(): number {
    return this.dashboard.archive === undefined ? 0 : this.dashboard.archive.deviceTotal;
  }

  getOperationsPrimaryValue(): number {
    return this.dashboard.operations === undefined ? 0 : this.dashboard.operations.taskPoolTotal;
  }

  getManagementPrimaryKey(): string {
    const management = this.dashboard.management;
    if (management === undefined) {
      return '';
    }

    if (management.reviewedTotal !== undefined) {
      return 'reviewedTotal';
    }
    if (management.pendingArchiveReviews !== undefined) {
      return 'pendingArchiveReviews';
    }
    if (management.pendingOperationsReviews !== undefined) {
      return 'pendingOperationsReviews';
    }

    return '';
  }

  getManagementPrimaryLabel(): string {
    const primaryKey = this.getManagementPrimaryKey();
    if (primaryKey === 'pendingArchiveReviews') {
      return '待审核档案操作';
    }
    if (primaryKey === 'pendingOperationsReviews') {
      return '待审核运维操作';
    }

    return '审核数';
  }

  getManagementPrimaryValue(): number {
    const management = this.dashboard.management;
    if (management === undefined) {
      return 0;
    }

    const primaryKey = this.getManagementPrimaryKey();
    if (primaryKey === 'pendingArchiveReviews') {
      return management.pendingArchiveReviews === undefined ? 0 : management.pendingArchiveReviews;
    }
    if (primaryKey === 'pendingOperationsReviews') {
      return management.pendingOperationsReviews === undefined ? 0 : management.pendingOperationsReviews;
    }

    return management.reviewedTotal === undefined ? 0 : management.reviewedTotal;
  }

  formatDashboardValue(value: number): string {
    if (!this.dashboardLoaded) {
      return '--';
    }

    return `${value}`;
  }

  getDashboardToneSurface(tone: string): string {
    if (tone === AppColors.Success) {
      return AppColors.SuccessSurface;
    }

    if (tone === AppColors.Warning) {
      return AppColors.WarningSurface;
    }

    return AppColors.PrimarySurface;
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
      this.actionMessageTargetId = `${MainPageActionId.ArchiveCenter}`;
    }
  }
}
