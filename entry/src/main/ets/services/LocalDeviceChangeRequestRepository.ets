import {
  DeviceArchiveChangeBaseline,
  DeviceArchiveChangeRequestForm,
  DeviceArchiveChangeRequestRecord,
  DeviceArchiveChangeRequestStatus
} from '../models/DeviceArchiveChangeModels';
import {
  DeviceArchiveChangeFieldDiff,
  DeviceArchiveReviewDecision,
  DeviceArchiveReviewItem,
  DeviceArchiveReviewResult
} from '../models/DeviceArchiveReviewModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

const LOCAL_REVIEW_SEEDS: DeviceArchiveReviewItem[] = [
  {
    id: 'DCR-LOCAL-0002',
    deviceCode: 'RDVP-DEVICE-0002',
    deviceName: '输送线B-02',
    applicantName: '本地用户',
    reason: '现场标识位置需要补充。',
    status: DeviceArchiveChangeRequestStatus.PendingReview,
    submittedAt: '2026-05-29 10:10',
    changes: [
      {
        field: 'location.address',
        label: '设备位置',
        oldValue: '二号厂房包装区',
        newValue: '二号厂房包装区A段'
      }
    ]
  }
];

export class LocalDeviceChangeRequestRepository {
  private static requests: DeviceArchiveReviewItem[] = LOCAL_REVIEW_SEEDS.map((item: DeviceArchiveReviewItem) => {
    return LocalDeviceChangeRequestRepository.cloneItem(item);
  });

  static appendFromSubmission(form: DeviceArchiveChangeRequestForm, record: DeviceArchiveChangeRequestRecord): void {
    LocalDeviceChangeRequestRepository.requests.unshift({
      id: record.id,
      deviceId: form.deviceId,
      deviceCode: record.deviceCode,
      deviceName: record.deviceName === undefined ? form.deviceName.trim() : record.deviceName,
      applicantName: '本地用户',
      reason: record.reason,
      status: DeviceArchiveChangeRequestStatus.PendingReview,
      submittedAt: record.submittedAt,
      changes: LocalDeviceChangeRequestRepository.buildDiffs(form)
    });
  }

  static listPending(): DeviceArchiveReviewItem[] {
    return LocalDeviceChangeRequestRepository.requests
      .filter((item: DeviceArchiveReviewItem) => item.status === DeviceArchiveChangeRequestStatus.PendingReview)
      .map((item: DeviceArchiveReviewItem) => LocalDeviceChangeRequestRepository.cloneItem(item));
  }

  static review(requestId: string, decision: DeviceArchiveReviewDecision, reviewComment: string): DeviceArchiveReviewResult | undefined {
    const request = LocalDeviceChangeRequestRepository.requests.find((item: DeviceArchiveReviewItem) => item.id === requestId);
    if (request === undefined || request.status !== DeviceArchiveChangeRequestStatus.PendingReview) {
      return undefined;
    }

    const reviewedAt = LocalDeviceChangeRequestRepository.formatDateTime(new Date());
    if (decision === DeviceArchiveReviewDecision.Approved) {
      const freezeUntil = new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString();
      request.status = DeviceArchiveChangeRequestStatus.Approved;
      LocalDeviceArchiveRepository.applyApprovedChange(request.deviceCode, request.changes, freezeUntil);
      LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '档案审核通过', request.deviceCode,
        LocalDeviceChangeRequestRepository.formatReviewDescription(reviewComment, true));
      return {
        id: request.id,
        status: request.status,
        reviewedAt,
        freezeUntil
      };
    }

    request.status = DeviceArchiveChangeRequestStatus.Rejected;
    LocalDeviceArchiveRepository.releaseChangeLock(request.deviceCode);
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '档案审核驳回', request.deviceCode,
      LocalDeviceChangeRequestRepository.formatReviewDescription(reviewComment, false));
    return {
      id: request.id,
      status: request.status,
      reviewedAt
    };
  }

  private static buildDiffs(form: DeviceArchiveChangeRequestForm): DeviceArchiveChangeFieldDiff[] {
    const baseline = form.baseline;
    const diffs: DeviceArchiveChangeFieldDiff[] = [];

    LocalDeviceChangeRequestRepository.appendDiff(diffs, baseline, 'name', '设备名称', 'deviceName', form.deviceName);
    LocalDeviceChangeRequestRepository.appendDiff(diffs, baseline, 'model', '设备型号', 'model', form.model);
    LocalDeviceChangeRequestRepository.appendDiff(diffs, baseline, 'manufacturer', '生产厂商', 'manufacturer',
      form.manufacturer);
    LocalDeviceChangeRequestRepository.appendDiff(diffs, baseline, 'location.address', '设备位置', 'locationAddress',
      form.locationAddress);

    return diffs;
  }

  private static appendDiff(diffs: DeviceArchiveChangeFieldDiff[], baseline: DeviceArchiveChangeBaseline | undefined,
    field: string, label: string, baselineField: string, newValue: string): void {
    const normalizedNewValue = newValue.trim();
    const oldValue = LocalDeviceChangeRequestRepository.getBaselineValue(baseline, baselineField);
    if (normalizedNewValue === oldValue.trim()) {
      return;
    }

    diffs.push({
      field,
      label,
      oldValue,
      newValue: normalizedNewValue
    });
  }

  private static getBaselineValue(baseline: DeviceArchiveChangeBaseline | undefined, field: string): string {
    if (baseline === undefined) {
      return '';
    }

    if (field === 'deviceName') {
      return baseline.deviceName;
    }

    if (field === 'model') {
      return baseline.model;
    }

    if (field === 'manufacturer') {
      return baseline.manufacturer;
    }

    if (field === 'locationAddress') {
      return baseline.locationAddress;
    }

    return '';
  }

  private static cloneItem(item: DeviceArchiveReviewItem): DeviceArchiveReviewItem {
    return {
      id: item.id,
      deviceId: item.deviceId,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      applicantName: item.applicantName,
      reason: item.reason,
      status: item.status,
      submittedAt: item.submittedAt,
      changes: item.changes.map((change: DeviceArchiveChangeFieldDiff): DeviceArchiveChangeFieldDiff => {
        return {
          field: change.field,
          label: change.label,
          oldValue: change.oldValue,
          newValue: change.newValue
        };
      })
    };
  }

  private static formatReviewDescription(reviewComment: string, approved: boolean): string {
    const normalizedComment = reviewComment.trim();
    if (normalizedComment.length === 0) {
      return approved ? '设备档案变更审核通过' : '设备档案变更审核驳回';
    }

    return approved ? `设备档案变更审核通过：${normalizedComment}` : `设备档案变更审核驳回：${normalizedComment}`;
  }

  private static formatDateTime(value: Date): string {
    return `${value.getFullYear()}-${LocalDeviceChangeRequestRepository.pad2(value.getMonth() + 1)}-${LocalDeviceChangeRequestRepository.pad2(value.getDate())} ${LocalDeviceChangeRequestRepository.pad2(value.getHours())}:${LocalDeviceChangeRequestRepository.pad2(value.getMinutes())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
