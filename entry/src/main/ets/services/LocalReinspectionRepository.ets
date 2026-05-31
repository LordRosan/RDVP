import { FaultSeverity } from '../models/FaultModels';
import {
  ReinspectionRecord,
  ReinspectionRecordForm,
  ReinspectionResult,
  ReinspectionTaskListResult,
  ReinspectionTaskStatus,
  ReinspectionTaskSummary
} from '../models/ReinspectionModels';
import { DeviceStatus } from '../models/DeviceModels';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { WorkbenchRefreshStore } from '../stores/WorkbenchRefreshStore';

const LOCAL_REINSPECTION_TASKS: ReinspectionTaskSummary[] = [
  {
    id: 'local-reinspection-0001',
    taskNo: 'RDI-LOCAL-0001',
    faultNo: 'RDF-LOCAL-0004',
    deviceCode: 'RDVP-DEVICE-0003',
    deviceName: '供能网关C-03',
    severity: FaultSeverity.Emergency,
    location: '二号厂房通信机柜',
    repairedAt: '2026-05-29 13:20',
    status: ReinspectionTaskStatus.Pending
  },
  {
    id: 'local-reinspection-0002',
    taskNo: 'RDI-LOCAL-0002',
    faultNo: 'RDF-LOCAL-0005',
    deviceCode: 'RDVP-DEVICE-0001',
    deviceName: '冷却泵A-01',
    severity: FaultSeverity.Severe,
    location: '一号厂房动力区',
    repairedAt: '2026-05-29 13:45',
    status: ReinspectionTaskStatus.Pending
  }
];

export interface LocalReinspectionTaskInput {
  faultNo: string;
  deviceCode: string;
  deviceName: string;
  severity: FaultSeverity;
  location: string;
  repairedAt: string;
}

export class LocalReinspectionRepository {
  private static tasks: ReinspectionTaskSummary[] = LOCAL_REINSPECTION_TASKS.map((item: ReinspectionTaskSummary) => {
    return LocalReinspectionRepository.cloneTask(item);
  });
  private static records: ReinspectionRecord[] = [];
  private static sequence: number = 100;

  static createPendingTask(input: LocalReinspectionTaskInput): ReinspectionTaskSummary {
    const sequenceText = LocalReinspectionRepository.nextSequenceText();
    const task: ReinspectionTaskSummary = {
      id: `local-reinspection-${sequenceText}`,
      taskNo: `RDI-LOCAL-${sequenceText}`,
      faultNo: input.faultNo,
      deviceCode: input.deviceCode,
      deviceName: input.deviceName,
      severity: input.severity,
      location: input.location,
      repairedAt: input.repairedAt,
      status: ReinspectionTaskStatus.Pending
    };

    LocalReinspectionRepository.tasks.unshift(task);
    WorkbenchRefreshStore.notifyChanged();
    return LocalReinspectionRepository.cloneTask(task);
  }

  static queryPendingTasks(): ReinspectionTaskListResult {
    const items = LocalReinspectionRepository.tasks
      .filter((item: ReinspectionTaskSummary) => {
        return item.status === ReinspectionTaskStatus.Pending;
      })
      .map((item: ReinspectionTaskSummary) => {
        return LocalReinspectionRepository.cloneTask(item);
      });

    return {
      items,
      total: items.length
    };
  }

  static submitRecord(form: ReinspectionRecordForm): ReinspectionRecord | undefined {
    const normalizedTaskId = form.taskId.trim();
    const task = LocalReinspectionRepository.tasks.find((item: ReinspectionTaskSummary) => {
      return item.id === normalizedTaskId || item.taskNo === normalizedTaskId;
    });

    if (task === undefined || task.status !== ReinspectionTaskStatus.Pending) {
      return undefined;
    }

    task.status = ReinspectionTaskStatus.Completed;
    LocalDeviceArchiveRepository.updateOperationalStatus(task.deviceCode,
      form.result === ReinspectionResult.Passed ? DeviceStatus.Normal : DeviceStatus.Faulted);
    const submittedAt = new Date().toISOString();
    const sequenceText = LocalReinspectionRepository.nextSequenceText();
    const record: ReinspectionRecord = {
      id: `local-reinspection-record-${sequenceText}`,
      recordNo: `RIR-LOCAL-${sequenceText}`,
      taskId: task.taskNo,
      result: form.result,
      submittedAt
    };
    LocalReinspectionRepository.records.unshift(record);
    WorkbenchRefreshStore.notifyChanged();
    return record;
  }

  static getPendingTaskCount(): number {
    return LocalReinspectionRepository.tasks.filter((item: ReinspectionTaskSummary) => {
      return item.status === ReinspectionTaskStatus.Pending;
    }).length;
  }

  private static cloneTask(item: ReinspectionTaskSummary): ReinspectionTaskSummary {
    return {
      id: item.id,
      taskNo: item.taskNo,
      faultNo: item.faultNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      severity: item.severity,
      location: item.location,
      repairedAt: item.repairedAt,
      status: item.status
    };
  }

  private static nextSequenceText(): string {
    LocalReinspectionRepository.sequence += 1;
    return `${LocalReinspectionRepository.sequence}`;
  }
}
