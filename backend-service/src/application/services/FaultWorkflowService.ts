import { AuditLogService } from '../../audit/AuditLogService.js';
import { badRequest, conflict, notFound, validationFailed } from '../../domain/errors.js';
import { GeoPoint, UserAccount } from '../../domain/models/entities.js';
import {
  DeviceStatus,
  FaultSeverity,
  FaultStatus,
  FaultType,
  ReinspectionResult,
  RepairerWorkloadStatus,
  RepairReportResult,
  RepairTaskStatus
} from '../../domain/models/enums.js';
import { resolveRepairTransition } from '../../domain/rules/faultRules.js';
import { InMemoryDatabase } from '../../infrastructure/InMemoryDatabase.js';

const DEFAULT_REPAIR_RADIUS_KM = 10;
const MIN_REPAIR_RADIUS_KM = 1;
const IDLE_MAX_REPAIR_RADIUS_KM = 20;
const LOW_LOAD_MAX_REPAIR_RADIUS_KM = 10;
const MAX_ACTIVE_REPAIR_TASK_COUNT = 2;

export class FaultWorkflowService {
  constructor(
    private readonly database: InMemoryDatabase,
    private readonly auditLogService: AuditLogService
  ) {}

  createFaultReport(input: {
    deviceCode: string;
    faultType: FaultType;
    severity: FaultSeverity;
    occurredAt: string;
    description: string;
    sceneCondition?: string;
    location?: GeoPoint;
    actor: UserAccount;
    requestId?: string;
  }) {
    const device = this.findDeviceByCode(input.deviceCode);
    this.assertEnumValue(FaultType, input.faultType, 'FAULT_TYPE_INVALID', 'Fault type is invalid.');
    this.assertEnumValue(FaultSeverity, input.severity, 'FAULT_SEVERITY_INVALID', 'Fault severity is invalid.');

    if (input.description.trim().length === 0) {
      throw validationFailed('VALIDATION_FAILED', 'Fault description is required.');
    }

    const now = this.database.now();
    const faultReport = {
      id: this.database.nextId('fault'),
      faultReportNo: this.database.nextBusinessNo('FR'),
      deviceId: device.id,
      reporterId: input.actor.id,
      faultType: input.faultType,
      severity: input.severity,
      description: input.description.trim(),
      sceneCondition: input.sceneCondition?.trim(),
      status: FaultStatus.PendingAcceptance,
      occurredAt: input.occurredAt,
      location: input.location,
      createdAt: now,
      updatedAt: now
    };

    this.database.faultReports.unshift(faultReport);
    device.status = DeviceStatus.Faulted;
    device.updatedAt = now;

    this.auditLogService.record({
      action: 'FAULT_REPORT',
      targetType: 'FAULT_REPORT',
      targetId: faultReport.id,
      targetNo: faultReport.faultReportNo,
      actor: input.actor,
      description: 'Created fault report.',
      requestId: input.requestId
    });

    return {
      id: faultReport.id,
      faultReportNo: faultReport.faultReportNo,
      status: faultReport.status,
      createdAt: faultReport.createdAt
    };
  }

  listAvailableRepairTasks(query: {
    longitude?: number;
    latitude?: number;
    radiusKm?: number;
    severity?: FaultSeverity;
    actor: UserAccount;
  }) {
    const radiusKm = query.radiusKm ?? DEFAULT_REPAIR_RADIUS_KM;
    if (radiusKm < MIN_REPAIR_RADIUS_KM || radiusKm > IDLE_MAX_REPAIR_RADIUS_KM) {
      throw validationFailed('REPAIR_TASK_RADIUS_INVALID', '查询范围必须在1到20公里之间。');
    }

    const workload = this.resolveRepairerWorkload(query.actor.id);
    this.assertWorkloadAllowsRefresh(workload, radiusKm);
    const hasPoint = query.longitude !== undefined && query.latitude !== undefined;

    const items = this.database.faultReports
      .filter((fault) => fault.status === FaultStatus.PendingAcceptance)
      .filter((fault) => query.severity === undefined || fault.severity === query.severity)
      .map((fault) => {
        const device = this.findDeviceById(fault.deviceId);
        const distanceKm = hasPoint && device.location.longitude !== undefined && device.location.latitude !== undefined
          ? this.distanceKm(query.latitude as number, query.longitude as number, device.location.latitude, device.location.longitude)
          : 0;
        return {
          id: fault.id,
          faultReportId: fault.id,
          faultReportNo: fault.faultReportNo,
          deviceCode: device.deviceCode,
          deviceName: device.name,
          faultType: fault.faultType,
          severity: fault.severity,
          distanceKm: Number(distanceKm.toFixed(1)),
          location: device.location,
          submittedAt: fault.createdAt,
          status: RepairTaskStatus.Available
        };
      })
      .filter((item) => !hasPoint || item.distanceKm <= radiusKm);

    return {
      radiusKm,
      workload,
      items,
      total: items.length
    };
  }

  acceptFaultReport(input: {
    faultReportId: string;
    acceptedLocation?: GeoPoint;
    actor: UserAccount;
    requestId?: string;
  }) {
    const fault = this.findFaultById(input.faultReportId);
    const workload = this.resolveRepairerWorkload(input.actor.id);
    this.assertWorkloadAllowsAccept(workload);

    const activeTask = this.database.repairTasks.find((task) => {
      return task.faultReportId === fault.id && task.status !== RepairTaskStatus.ReportSubmitted;
    });

    if (activeTask !== undefined || fault.status !== FaultStatus.PendingAcceptance) {
      throw conflict('FAULT_ALREADY_ACCEPTED', 'Fault has already been accepted.');
    }

    if (input.acceptedLocation !== undefined) {
      const targetDevice = this.findDeviceById(fault.deviceId);
      if (targetDevice.location.longitude !== undefined && targetDevice.location.latitude !== undefined) {
        const distanceKm = this.distanceKm(
          input.acceptedLocation.latitude,
          input.acceptedLocation.longitude,
          targetDevice.location.latitude,
          targetDevice.location.longitude
        );
        if (distanceKm > workload.maxRadiusKm) {
          throw validationFailed(
            'REPAIR_TASK_OUT_OF_WORKLOAD_RANGE',
            `当前处于${workload.label}状态，仅可接取${workload.maxRadiusKm}公里内的维修任务。`
          );
        }
      }
    }

    const now = this.database.now();
    const repairTask = {
      id: this.database.nextId('repair_task'),
      repairTaskNo: this.database.nextBusinessNo('RT'),
      faultReportId: fault.id,
      maintainerId: input.actor.id,
      status: RepairTaskStatus.Accepted,
      acceptedLocation: input.acceptedLocation,
      acceptedAt: now,
      createdAt: now,
      updatedAt: now
    };

    this.database.repairTasks.unshift(repairTask);
    fault.status = FaultStatus.Accepted;
    fault.acceptedTaskId = repairTask.id;
    fault.updatedAt = now;

    const device = this.findDeviceById(fault.deviceId);
    device.status = DeviceStatus.UnderRepair;
    device.updatedAt = now;

    this.auditLogService.record({
      action: 'REPAIR_TASK_ACCEPT',
      targetType: 'FAULT_REPORT',
      targetId: fault.id,
      targetNo: fault.faultReportNo,
      actor: input.actor,
      description: 'Accepted fault repair task.',
      requestId: input.requestId
    });

    return {
      repairTaskId: repairTask.id,
      faultReportId: fault.id,
      status: repairTask.status,
      acceptedAt: repairTask.acceptedAt
    };
  }

  listMyRepairTasks(input: { actor: UserAccount; status?: RepairTaskStatus }) {
    return this.database.repairTasks
      .filter((task) => task.maintainerId === input.actor.id)
      .filter((task) => {
        if (input.status !== undefined) {
          return task.status === input.status;
        }

        return task.status !== RepairTaskStatus.ReportSubmitted;
      })
      .map((task) => {
        const fault = this.findFaultById(task.faultReportId);
        const device = this.findDeviceById(fault.deviceId);
        return {
          id: task.id,
          repairTaskNo: task.repairTaskNo,
          faultReportNo: fault.faultReportNo,
          deviceCode: device.deviceCode,
          deviceName: device.name,
          faultType: fault.faultType,
          severity: fault.severity,
          acceptedAt: task.acceptedAt,
          status: task.status
        };
      });
  }

  submitRepairReport(input: {
    repairTaskId: string;
    result: RepairReportResult;
    repairedAt: string;
    processDescription: string;
    partsUsed?: string;
    actor: UserAccount;
    requestId?: string;
  }) {
    this.assertEnumValue(RepairReportResult, input.result, 'REPAIR_RESULT_INVALID', 'Repair result is invalid.');
    if (input.processDescription.trim().length === 0) {
      throw validationFailed('VALIDATION_FAILED', 'Repair process description is required.');
    }

    const task = this.database.repairTasks.find((item) => item.id === input.repairTaskId || item.repairTaskNo === input.repairTaskId);
    if (task === undefined) {
      throw notFound('REPAIR_TASK_NOT_FOUND', 'Repair task not found.');
    }

    if (task.maintainerId !== input.actor.id) {
      throw validationFailed('REPAIR_TASK_STATUS_INVALID', 'Repair task does not belong to current user.');
    }

    if (![RepairTaskStatus.Accepted, RepairTaskStatus.Processing].includes(task.status)) {
      throw validationFailed('REPAIR_TASK_STATUS_INVALID', 'Repair task status does not allow report submission.');
    }

    const fault = this.findFaultById(task.faultReportId);
    const device = this.findDeviceById(fault.deviceId);
    const transition = resolveRepairTransition(fault.severity, input.result);
    const now = this.database.now();

    const repairReport = {
      id: this.database.nextId('repair_report'),
      repairReportNo: this.database.nextBusinessNo('RR'),
      repairTaskId: task.id,
      faultReportId: fault.id,
      maintainerId: input.actor.id,
      result: input.result,
      repairedAt: input.repairedAt,
      processDescription: input.processDescription.trim(),
      partsUsed: input.partsUsed?.trim(),
      requiresReinspection: transition.requiresReinspection,
      createdAt: now
    };

    this.database.repairReports.unshift(repairReport);
    task.status = RepairTaskStatus.ReportSubmitted;
    task.completedAt = now;
    task.updatedAt = now;
    fault.status = transition.faultStatus;
    fault.updatedAt = now;
    if (transition.faultStatus === FaultStatus.Closed) {
      fault.closedAt = now;
    }
    device.status = transition.deviceStatus;
    device.updatedAt = now;

    this.auditLogService.record({
      action: 'REPAIR_REPORT',
      targetType: 'REPAIR_REPORT',
      targetId: repairReport.id,
      targetNo: repairReport.repairReportNo,
      actor: input.actor,
      description: 'Submitted repair report.',
      requestId: input.requestId
    });

    return {
      id: repairReport.id,
      repairReportNo: repairReport.repairReportNo,
      repairTaskId: task.id,
      faultReportId: fault.id,
      result: repairReport.result,
      nextStatus: transition.faultStatus,
      requiresReinspection: repairReport.requiresReinspection,
      createdAt: repairReport.createdAt
    };
  }

  listPendingReinspections() {
    return this.database.faultReports
      .filter((fault) => fault.status === FaultStatus.PendingReinspection)
      .map((fault) => {
        const device = this.findDeviceById(fault.deviceId);
        const repairReport = this.findLatestRepairReport(fault.id);
        return {
          id: fault.id,
          faultReportId: fault.id,
          faultReportNo: fault.faultReportNo,
          deviceCode: device.deviceCode,
          deviceName: device.name,
          severity: fault.severity,
          location: device.location,
          repairedAt: repairReport?.repairedAt,
          status: fault.status
        };
      });
  }

  submitReinspectionRecord(input: {
    faultReportId: string;
    result: ReinspectionResult;
    reinspectedAt: string;
    description?: string;
    actor: UserAccount;
    requestId?: string;
  }) {
    this.assertEnumValue(ReinspectionResult, input.result, 'REINSPECTION_RESULT_INVALID', 'Reinspection result is invalid.');
    const fault = this.findFaultById(input.faultReportId);
    if (fault.status !== FaultStatus.PendingReinspection) {
      throw validationFailed('REINSPECTION_REQUIRED', 'Current fault is not pending reinspection.');
    }

    const repairReport = this.findLatestRepairReport(fault.id);
    if (repairReport === undefined) {
      throw notFound('REPAIR_REPORT_NOT_FOUND', 'Repair report not found.');
    }

    const device = this.findDeviceById(fault.deviceId);
    const now = this.database.now();
    const record = {
      id: this.database.nextId('reinspection'),
      reinspectionRecordNo: this.database.nextBusinessNo('RI'),
      faultReportId: fault.id,
      repairReportId: repairReport.id,
      reinspectorId: input.actor.id,
      result: input.result,
      description: input.description?.trim(),
      reinspectedAt: input.reinspectedAt,
      createdAt: now
    };

    this.database.reinspectionRecords.unshift(record);

    if (input.result === ReinspectionResult.Passed) {
      fault.status = FaultStatus.Closed;
      fault.closedAt = now;
      device.status = DeviceStatus.Normal;
    } else {
      fault.status = FaultStatus.PendingAcceptance;
      delete fault.acceptedTaskId;
      device.status = DeviceStatus.Faulted;
    }
    fault.updatedAt = now;
    device.updatedAt = now;

    this.auditLogService.record({
      action: 'REINSPECTION_RECORD',
      targetType: 'FAULT_REPORT',
      targetId: fault.id,
      targetNo: fault.faultReportNo,
      actor: input.actor,
      description: 'Submitted reinspection record.',
      requestId: input.requestId
    });

    return {
      id: record.id,
      reinspectionRecordNo: record.reinspectionRecordNo,
      faultReportId: fault.id,
      result: record.result,
      nextFaultStatus: fault.status,
      nextDeviceStatus: device.status,
      createdAt: record.createdAt
    };
  }

  private findDeviceByCode(deviceCode: string) {
    const normalizedDeviceCode = deviceCode.trim().toUpperCase();
    const device = this.database.devices.find((item) => item.deviceCode === normalizedDeviceCode);
    if (device === undefined) {
      throw notFound('DEVICE_NOT_FOUND', 'Device not found.');
    }

    return device;
  }

  private findDeviceById(deviceId: string) {
    const device = this.database.devices.find((item) => item.id === deviceId);
    if (device === undefined) {
      throw notFound('DEVICE_NOT_FOUND', 'Device not found.');
    }

    return device;
  }

  private findFaultById(faultReportId: string) {
    const fault = this.database.faultReports.find((item) => item.id === faultReportId || item.faultReportNo === faultReportId);
    if (fault === undefined) {
      throw notFound('FAULT_REPORT_NOT_FOUND', 'Fault report not found.');
    }

    return fault;
  }

  private findLatestRepairReport(faultReportId: string) {
    return this.database.repairReports.find((item) => item.faultReportId === faultReportId);
  }

  private resolveRepairerWorkload(maintainerId: string) {
    const activeTaskCount = this.database.repairTasks.filter((task) => {
      return task.maintainerId === maintainerId &&
        [RepairTaskStatus.Accepted, RepairTaskStatus.Processing].includes(task.status);
    }).length;

    if (activeTaskCount >= MAX_ACTIVE_REPAIR_TASK_COUNT) {
      return {
        status: RepairerWorkloadStatus.Busy,
        label: '忙碌',
        activeTaskCount,
        maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
        maxRadiusKm: 0,
        recommendedRadiusKm: 0,
        message: '当前进行中的维修任务已达到上限，暂不可继续接取。请完成并提交维修报告后再刷新任务。',
        canAccept: false
      };
    }

    if (activeTaskCount > 0) {
      return {
        status: RepairerWorkloadStatus.LowLoad,
        label: '低负载',
        activeTaskCount,
        maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
        maxRadiusKm: LOW_LOAD_MAX_REPAIR_RADIUS_KM,
        recommendedRadiusKm: LOW_LOAD_MAX_REPAIR_RADIUS_KM,
        message: '当前已有进行中的维修任务，系统已限制可接取范围。请优先处理已接取任务。',
        canAccept: true
      };
    }

    return {
      status: RepairerWorkloadStatus.Idle,
      label: '空闲',
      activeTaskCount,
      maxActiveTaskCount: MAX_ACTIVE_REPAIR_TASK_COUNT,
      maxRadiusKm: IDLE_MAX_REPAIR_RADIUS_KM,
      recommendedRadiusKm: DEFAULT_REPAIR_RADIUS_KM,
      message: '当前无进行中的维修任务，可接取服务范围内的故障任务。',
      canAccept: true
    };
  }

  private assertWorkloadAllowsRefresh(
    workload: ReturnType<FaultWorkflowService['resolveRepairerWorkload']>,
    radiusKm: number
  ): void {
    this.assertWorkloadAllowsAccept(workload);
    if (radiusKm > workload.maxRadiusKm) {
      throw validationFailed(
        'REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD',
        `当前处于${workload.label}状态，查询范围不能超过${workload.maxRadiusKm}公里。`
      );
    }
  }

  private assertWorkloadAllowsAccept(workload: ReturnType<FaultWorkflowService['resolveRepairerWorkload']>): void {
    if (!workload.canAccept) {
      throw conflict('REPAIRER_BUSY', workload.message);
    }
  }

  private assertEnumValue<T extends Record<string, string>>(
    enumType: T,
    value: string,
    code: string,
    message: string
  ): void {
    if (!Object.values(enumType).includes(value)) {
      throw badRequest(code, message);
    }
  }

  private distanceKm(latitude1: number, longitude1: number, latitude2: number, longitude2: number): number {
    const earthRadiusKm = 6371;
    const dLat = this.toRadians(latitude2 - latitude1);
    const dLon = this.toRadians(longitude2 - longitude1);
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(this.toRadians(latitude1)) * Math.cos(this.toRadians(latitude2)) * Math.sin(dLon / 2) ** 2;
    return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  private toRadians(value: number): number {
    return value * Math.PI / 180;
  }
}
