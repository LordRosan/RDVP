import { ActionTile } from '../components/ActionTile';
import { MetricTile } from '../components/MetricTile';
import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/WorkbenchModels';
import { CurrentUserSnapshot } from '../models/SessionModels';
import { WorkbenchService } from '../services/WorkbenchService';
import { SessionStore } from '../stores/SessionStore';
import { formatConnectionStatus } from '../utils/SessionFormat';

@Entry
@Component
struct Index {
  private metrics: WorkbenchMetric[] = WorkbenchService.getMetrics();
  private actions: WorkbenchAction[] = WorkbenchService.getActions();
  private statusItems: WorkbenchStatusItem[] = WorkbenchService.getStatusItems();
  private currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State activeActionId: WorkbenchActionId = WorkbenchActionId.DeviceCodeSearch;
  @State activeActionTitle: string = '设备编号查询';

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.Header()
        this.MetricSection()
        this.ActionSection()
        this.StatusSection()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: 18,
        right: 18,
        top: 18,
        bottom: 28
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  Header() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('RDVP')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)

          Text('远程设备核验与运维报告系统')
            .fontSize(13)
            .fontColor('#5B6472')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text(this.currentUser.displayName)
            .fontSize(13)
            .fontColor('#111827')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.currentUser.roleName)
            .fontSize(11)
            .fontColor('#6B7280')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(formatConnectionStatus(this.currentUser.online))
            .fontSize(11)
            .fontColor(this.currentUser.online ? '#087F5B' : '#D9480F')
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.End)
        .padding({
          left: 12,
          right: 12,
          top: 8,
          bottom: 8
        })
        .borderRadius(8)
        .backgroundColor('#FFFFFF')
        .border({
          width: 1,
          color: '#E5E7EB'
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('当前入口')
          .fontSize(13)
          .fontColor('#6B7280')

        Text(this.activeActionTitle)
          .fontSize(14)
          .fontColor('#111827')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({
        left: 14,
        right: 14,
        top: 11,
        bottom: 11
      })
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .border({
        width: 1,
        color: '#E5E7EB'
      })
    }
    .width('100%')
  }

  @Builder
  MetricSection() {
    Column({ space: 12 }) {
      Text('工作概览')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Grid() {
        ForEach(this.metrics, (item: WorkbenchMetric) => {
          GridItem() {
            MetricTile({ metric: item })
          }
        }, (item: WorkbenchMetric) => item.id)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      Text('核心业务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Grid() {
        ForEach(this.actions, (item: WorkbenchAction) => {
          GridItem() {
            ActionTile({
              action: item,
              active: this.activeActionId === item.id
            })
              .onClick(() => {
                this.activeActionId = item.id;
                this.activeActionTitle = item.title;
              })
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
  StatusSection() {
    Column({ space: 12 }) {
      Text('系统状态')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Column() {
        ForEach(this.statusItems, (item: WorkbenchStatusItem) => {
          Row() {
            Text(item.name)
              .fontSize(14)
              .fontColor('#374151')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(item.value)
              .fontSize(13)
              .fontColor(item.tone)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .height(44)
          .width('100%')
          .padding({
            left: 14,
            right: 14
          })
        }, (item: WorkbenchStatusItem) => item.id)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .border({
        width: 1,
        color: '#E5E7EB'
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
