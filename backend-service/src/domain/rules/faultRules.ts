import { DeviceStatus, FaultSeverity, FaultStatus, RepairReportResult } from '../models/enums.js';

export interface RepairTransition {
  faultStatus: FaultStatus;
  deviceStatus: DeviceStatus;
  requiresReinspection: boolean;
}

const REINSPECTION_SEVERITIES = new Set<FaultSeverity>([
  FaultSeverity.Emergency,
  FaultSeverity.Severe
]);

export function resolveRepairTransition(severity: FaultSeverity, result: RepairReportResult): RepairTransition {
  if (result === RepairReportResult.Unresolved) {
    return {
      faultStatus: FaultStatus.UnderRepair,
      deviceStatus: DeviceStatus.UnderRepair,
      requiresReinspection: false
    };
  }

  if (REINSPECTION_SEVERITIES.has(severity)) {
    return {
      faultStatus: FaultStatus.PendingReinspection,
      deviceStatus: DeviceStatus.PendingReinspection,
      requiresReinspection: true
    };
  }

  return {
    faultStatus: FaultStatus.Closed,
    deviceStatus: DeviceStatus.Normal,
    requiresReinspection: false
  };
}
