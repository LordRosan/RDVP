import { FaultReportForm, FaultReportRecord, FaultSeverity, FaultStatus, FaultType } from '../models/FaultModels';
import { DeviceStatus } from '../models/DeviceModels';
import {
  AvailableRepairTaskListResult,
  AvailableRepairTaskSummary,
  MyRepairTaskListResult,
  MyRepairTaskSummary,
  RepairReportForm,
  RepairReportRecord,
  RepairReportResult,
  RepairTaskAcceptResult,
  RepairTaskStatus
} from '../models/RepairTaskModels';
import { DeviceService } from './DeviceService';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalReinspectionRepository } from './LocalReinspectionRepository';
import { WorkbenchRefreshStore } from '../stores/WorkbenchRefreshStore';

interface LocalRepairTaskSeed {
  id: string;
  faultNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: FaultType;
  severity: FaultSeverity;
  distanceKm: number;
  location: string;
  submittedAt: string;
}

const LOCAL_AVAILABLE_TASK_SEEDS: LocalRepairTaskSeed[] = [
  {
    id: 'local-task-0001',
    faultNo: 'RDF-LOCAL-0001',
    deviceCode: 'RDVP-DEVICE-0001',
    deviceName: '冷却泵A-01',
    faultType: FaultType.OperationAbnormal,
    severity: FaultSeverity.General,
    distanceKm: 3.8,
    location: '一号厂房动力区',
    submittedAt: '2026-05-29 09:40'
  }
];

const LOCAL_MY_TASK_SEEDS: MyRepairTaskSummary[] = [
  {
    id: 'local-my-task-0001',
    taskNo: 'RDT-LOCAL-0001',
    faultNo: 'RDF-LOCAL-0003',
    deviceCode: 'RDVP-DEVICE-0002',
    deviceName: '输送线B-02',
    faultType: FaultType.HardwareDamage,
    severity: FaultSeverity.General,
    acceptedAt: '2026-05-29 10:50',
    status: RepairTaskStatus.Accepted
  }
];

export class LocalRepairTaskRepository {
  private static availableTasks: AvailableRepairTaskSummary[] =
    LocalRepairTaskRepository.createAvailableSeeds();
  private static myTasks: MyRepairTaskSummary[] = LOCAL_MY_TASK_SEEDS.map((item: MyRepairTaskSummary) => {
    return LocalRepairTaskRepository.cloneMyTask(item);
  });
  private static reports: RepairReportRecord[] = [];
  private static sequence: number = 100;

  static createFaultReport(form: FaultReportForm): FaultReportRecord | undefined {
    const submittedAt = LocalRepairTaskRepository.formatDateTime(new Date());
    const deviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);
    if (LocalRepairTaskRepository.hasActiveFaultForDevice(deviceCode)) {
      return undefined;
    }

    const sequenceText = LocalRepairTaskRepository.nextSequenceText();
    const faultNo = `RDF-LOCAL-${sequenceText}`;

    const record: FaultReportRecord = {
      id: `local-fault-${sequenceText}`,
      reportNo: faultNo,
      deviceCode,
      faultType: form.faultType,
      severity: form.severity,
      status: FaultStatus.PendingAcceptance,
      submittedAt
    };

    LocalRepairTaskRepository.availableTasks.unshift({
      id: `local-task-${sequenceText}`,
      faultNo,
      deviceCode,
      deviceName: LocalRepairTaskRepository.resolveDeviceName(deviceCode),
      faultType: form.faultType,
      severity: form.severity,
      distanceKm: LocalRepairTaskRepository.resolveLocalDistance(form.severity),
      location: LocalRepairTaskRepository.resolveDeviceLocation(deviceCode),
      submittedAt,
      status: RepairTaskStatus.Available
    });
    LocalDeviceArchiveRepository.updateOperationalStatus(deviceCode, DeviceStatus.Faulted);
    WorkbenchRefreshStore.notifyChanged();

    return record;
  }

  static hasActiveFaultForDevice(deviceCode: string): boolean {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    if (normalizedDeviceCode.length === 0) {
      return false;
    }

    const device = LocalDeviceArchiveRepository.findByCode(normalizedDeviceCode);
    if (device !== undefined &&
      (device.status === DeviceStatus.Faulted ||
        device.status === DeviceStatus.UnderRepair ||
        device.status === DeviceStatus.PendingReinspection)) {
      return true;
    }

    const hasAvailableTask = LocalRepairTaskRepository.availableTasks.some((item: AvailableRepairTaskSummary) => {
      return item.deviceCode === normalizedDeviceCode && item.status === RepairTaskStatus.Available;
    });
    if (hasAvailableTask) {
      return true;
    }

    const hasActiveMyTask = LocalRepairTaskRepository.myTasks.some((item: MyRepairTaskSummary) => {
      return item.deviceCode === normalizedDeviceCode && item.status !== RepairTaskStatus.ReportSubmitted;
    });
    if (hasActiveMyTask) {
      return true;
    }

    return LocalReinspectionRepository.hasPendingTaskForDevice(normalizedDeviceCode);
  }

  static queryAvailableTasks(radiusKm: number): AvailableRepairTaskListResult {
    const items = LocalRepairTaskRepository.availableTasks
      .filter((item: AvailableRepairTaskSummary) => {
        return item.status === RepairTaskStatus.Available &&
          item.distanceKm !== undefined &&
          item.distanceKm <= radiusKm;
      })
      .map((item: AvailableRepairTaskSummary) => {
        return LocalRepairTaskRepository.cloneAvailableTask(item);
      });

    return {
      radiusKm,
      items,
      total: items.length
    };
  }

  static acceptTask(taskId: string): RepairTaskAcceptResult | undefined {
    const normalizedTaskId = taskId.trim();
    const taskIndex = LocalRepairTaskRepository.availableTasks.findIndex((item: AvailableRepairTaskSummary) => {
      return item.id === normalizedTaskId || item.faultNo === normalizedTaskId;
    });

    if (taskIndex < 0) {
      return undefined;
    }

    const availableTask = LocalRepairTaskRepository.availableTasks[taskIndex];
    LocalRepairTaskRepository.availableTasks.splice(taskIndex, 1);

    const acceptedAt = LocalRepairTaskRepository.formatDateTime(new Date());
    const taskNo = `RDT-LOCAL-${LocalRepairTaskRepository.nextSequenceText()}`;
    LocalRepairTaskRepository.myTasks.unshift({
      id: availableTask.id,
      taskNo,
      faultNo: availableTask.faultNo,
      deviceCode: availableTask.deviceCode,
      deviceName: availableTask.deviceName,
      faultType: availableTask.faultType,
      severity: availableTask.severity,
      acceptedAt,
      status: RepairTaskStatus.Accepted
    });
    LocalDeviceArchiveRepository.updateOperationalStatus(availableTask.deviceCode, DeviceStatus.UnderRepair);
    WorkbenchRefreshStore.notifyChanged();

    return {
      taskId: taskNo,
      status: RepairTaskStatus.Accepted,
      acceptedAt
    };
  }

  static queryMyTasks(): MyRepairTaskListResult {
    const items = LocalRepairTaskRepository.myTasks
      .filter((item: MyRepairTaskSummary) => {
        return item.status !== RepairTaskStatus.ReportSubmitted;
      })
      .map((item: MyRepairTaskSummary) => {
        return LocalRepairTaskRepository.cloneMyTask(item);
      });

    return {
      items,
      total: items.length
    };
  }

  static submitRepairReport(form: RepairReportForm): RepairReportRecord | undefined {
    const normalizedTaskId = form.taskId.trim();
    const task = LocalRepairTaskRepository.myTasks.find((item: MyRepairTaskSummary) => {
      return item.id === normalizedTaskId || item.taskNo === normalizedTaskId;
    });

    if (task === undefined || task.status === RepairTaskStatus.ReportSubmitted) {
      return undefined;
    }

    task.status = RepairTaskStatus.ReportSubmitted;
    LocalRepairTaskRepository.syncDeviceAfterRepairReport(task, form);

    const submittedAt = LocalRepairTaskRepository.formatDateTime(new Date());
    const sequenceText = LocalRepairTaskRepository.nextSequenceText();
    const report: RepairReportRecord = {
      id: `local-repair-report-${sequenceText}`,
      reportNo: `RDR-LOCAL-${sequenceText}`,
      taskId: task.taskNo,
      result: form.result,
      submittedAt
    };
    LocalRepairTaskRepository.reports.unshift(report);
    WorkbenchRefreshStore.notifyChanged();
    return report;
  }

  static getPendingAvailableTaskCount(): number {
    return LocalRepairTaskRepository.availableTasks.filter((item: AvailableRepairTaskSummary) => {
      return item.status === RepairTaskStatus.Available;
    }).length;
  }

  static getActiveMyTaskCount(): number {
    return LocalRepairTaskRepository.myTasks.filter((item: MyRepairTaskSummary) => {
      return item.status !== RepairTaskStatus.ReportSubmitted;
    }).length;
  }

  static getAvailableTaskDistanceKm(taskId: string): number | undefined {
    const normalizedTaskId = taskId.trim();
    const task = LocalRepairTaskRepository.availableTasks.find((item: AvailableRepairTaskSummary) => {
      return item.id === normalizedTaskId || item.faultNo === normalizedTaskId;
    });

    if (task === undefined || task.status !== RepairTaskStatus.Available) {
      return undefined;
    }

    return task.distanceKm;
  }

  private static createAvailableSeeds(): AvailableRepairTaskSummary[] {
    return LOCAL_AVAILABLE_TASK_SEEDS.map((item: LocalRepairTaskSeed): AvailableRepairTaskSummary => {
      return {
        id: item.id,
        faultNo: item.faultNo,
        deviceCode: item.deviceCode,
        deviceName: item.deviceName,
        faultType: item.faultType,
        severity: item.severity,
        distanceKm: item.distanceKm,
        location: item.location,
        submittedAt: item.submittedAt,
        status: RepairTaskStatus.Available
      };
    });
  }

  private static cloneAvailableTask(item: AvailableRepairTaskSummary): AvailableRepairTaskSummary {
    return {
      id: item.id,
      faultNo: item.faultNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      faultType: item.faultType,
      severity: item.severity,
      distanceKm: item.distanceKm,
      location: item.location,
      submittedAt: item.submittedAt,
      status: item.status
    };
  }

  private static cloneMyTask(item: MyRepairTaskSummary): MyRepairTaskSummary {
    return {
      id: item.id,
      taskNo: item.taskNo,
      faultNo: item.faultNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      faultType: item.faultType,
      severity: item.severity,
      acceptedAt: item.acceptedAt,
      status: item.status
    };
  }

  private static resolveDeviceName(deviceCode: string): string {
    if (deviceCode === 'RDVP-DEVICE-0001') {
      return '冷却泵A-01';
    }

    if (deviceCode === 'RDVP-DEVICE-0002') {
      return '视觉采集终端B-02';
    }

    if (deviceCode === 'RDVP-DEVICE-0003') {
      return '供能网关C-03';
    }

    return '未命名设备';
  }

  private static resolveDeviceLocation(deviceCode: string): string {
    if (deviceCode === 'RDVP-DEVICE-0001') {
      return '一号厂房动力区';
    }

    if (deviceCode === 'RDVP-DEVICE-0002') {
      return '一号厂房检测线';
    }

    if (deviceCode === 'RDVP-DEVICE-0003') {
      return '二号厂房通信机柜';
    }

    return '待补充位置';
  }

  private static resolveLocalDistance(severity: FaultSeverity): number {
    switch (severity) {
      case FaultSeverity.Emergency:
        return 2.4;
      case FaultSeverity.Severe:
        return 4.8;
      case FaultSeverity.General:
        return 7.2;
      case FaultSeverity.Minor:
      default:
        return 9.5;
    }
  }

  private static syncDeviceAfterRepairReport(task: MyRepairTaskSummary, form: RepairReportForm): void {
    if (form.result === RepairReportResult.Unresolved) {
      LocalDeviceArchiveRepository.updateOperationalStatus(task.deviceCode, DeviceStatus.UnderRepair);
      return;
    }

    if (LocalRepairTaskRepository.requiresReinspection(task.severity)) {
      LocalDeviceArchiveRepository.updateOperationalStatus(task.deviceCode, DeviceStatus.PendingReinspection);
      LocalReinspectionRepository.createPendingTask({
        faultNo: task.faultNo,
        deviceCode: task.deviceCode,
        deviceName: task.deviceName,
        severity: task.severity,
        location: LocalRepairTaskRepository.resolveDeviceLocation(task.deviceCode),
        repairedAt: form.repairedAt.trim()
      });
      return;
    }

    LocalDeviceArchiveRepository.updateOperationalStatus(task.deviceCode, DeviceStatus.Normal);
  }

  private static requiresReinspection(severity: FaultSeverity): boolean {
    return severity === FaultSeverity.Emergency || severity === FaultSeverity.Severe;
  }

  private static nextSequenceText(): string {
    LocalRepairTaskRepository.sequence += 1;
    return `${LocalRepairTaskRepository.sequence}`;
  }

  private static formatDateTime(value: Date): string {
    return `${value.getFullYear()}-${LocalRepairTaskRepository.pad2(value.getMonth() + 1)}-${LocalRepairTaskRepository.pad2(value.getDate())} ${LocalRepairTaskRepository.pad2(value.getHours())}:${LocalRepairTaskRepository.pad2(value.getMinutes())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
