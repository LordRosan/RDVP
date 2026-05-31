export interface FaultReportPrefill {
  deviceCode: string;
  description: string;
  sceneCondition: string;
}

export class OperationsFlowStore {
  private static faultReportPrefill?: FaultReportPrefill = undefined;

  static setFaultReportPrefill(prefill: FaultReportPrefill): void {
    OperationsFlowStore.faultReportPrefill = {
      deviceCode: prefill.deviceCode,
      description: prefill.description,
      sceneCondition: prefill.sceneCondition
    };
  }

  static consumeFaultReportPrefill(): FaultReportPrefill | undefined {
    const prefill = OperationsFlowStore.faultReportPrefill;
    OperationsFlowStore.faultReportPrefill = undefined;
    return prefill;
  }
}
