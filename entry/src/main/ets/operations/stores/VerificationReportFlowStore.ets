import { VerificationReportForm } from '../models/VerificationReportModels';

export class VerificationReportFlowStore {
  private static pendingAbnormalVerification?: VerificationReportForm = undefined;
  private static faultReportSubmitted: boolean = false;
  private static faultReportDiscarded: boolean = false;

  static startFaultReportFlow(form: VerificationReportForm): void {
    VerificationReportFlowStore.pendingAbnormalVerification = {
      deviceCode: form.deviceCode,
      result: form.result,
      description: form.description,
      verifiedAt: form.verifiedAt,
      remark: form.remark
    };
    VerificationReportFlowStore.faultReportSubmitted = false;
    VerificationReportFlowStore.faultReportDiscarded = false;
  }

  static getPendingAbnormalVerification(): VerificationReportForm | undefined {
    const form = VerificationReportFlowStore.pendingAbnormalVerification;
    if (form === undefined) {
      return undefined;
    }

    return {
      deviceCode: form.deviceCode,
      result: form.result,
      description: form.description,
      verifiedAt: form.verifiedAt,
      remark: form.remark
    };
  }

  static clearFlow(): void {
    VerificationReportFlowStore.pendingAbnormalVerification = undefined;
    VerificationReportFlowStore.faultReportSubmitted = false;
    VerificationReportFlowStore.faultReportDiscarded = false;
  }

  static markFaultReportSubmitted(): void {
    VerificationReportFlowStore.pendingAbnormalVerification = undefined;
    VerificationReportFlowStore.faultReportSubmitted = true;
    VerificationReportFlowStore.faultReportDiscarded = false;
  }

  static consumeFaultReportSubmitted(): boolean {
    const submitted = VerificationReportFlowStore.faultReportSubmitted;
    VerificationReportFlowStore.faultReportSubmitted = false;
    return submitted;
  }

  static markFaultReportDiscarded(): void {
    VerificationReportFlowStore.pendingAbnormalVerification = undefined;
    VerificationReportFlowStore.faultReportSubmitted = false;
    VerificationReportFlowStore.faultReportDiscarded = true;
  }

  static consumeFaultReportDiscarded(): boolean {
    const discarded = VerificationReportFlowStore.faultReportDiscarded;
    VerificationReportFlowStore.faultReportDiscarded = false;
    return discarded;
  }
}
