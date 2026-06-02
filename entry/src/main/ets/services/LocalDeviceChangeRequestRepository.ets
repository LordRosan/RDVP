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
  DeviceArchiveReviewRequestType,
  DeviceArchiveReviewResult
} from '../models/DeviceArchiveReviewModels';
import { DeviceSummary } from '../models/DeviceModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { SessionStore } from '../stores/SessionStore';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

const LOCAL_REVIEW_SEEDS: DeviceArchiveReviewItem[] = [
  {
    id: 'DCR-LOCAL-0002',
    type: DeviceArchiveReviewRequestType.Update,
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

  static appendFromSubmission(form: DeviceArchiveChangeRequestForm, record: DeviceArchiveChangeRequestRecord,
    applicantName: string): void {
    LocalDeviceChangeRequestRepository.requests.unshift({
      id: record.id,
      type: DeviceArchiveReviewRequestType.Update,
      deviceId: form.deviceId,
      deviceCode: record.deviceCode,
      deviceName: record.deviceName === undefined ? form.deviceName.trim() : record.deviceName,
      applicantName,
      reason: record.reason,
      status: DeviceArchiveChangeRequestStatus.PendingReview,
      submittedAt: record.submittedAt,
      changes: LocalDeviceChangeRequestRepository.buildDiffs(form)
    });
  }

  static appendCreateSubmission(deviceCode: string, deviceName: string, model: string, manufacturer: string,
    locationAddress: string, reason: string, requestId: string, submittedAt: string, applicantName: string): void {
    LocalDeviceChangeRequestRepository.requests.unshift({
      id: requestId,
      type: DeviceArchiveReviewRequestType.Create,
      deviceCode,
      deviceName,
      applicantName,
      reason,
      status: DeviceArchiveChangeRequestStatus.PendingReview,
      submittedAt,
      changes: LocalDeviceChangeRequestRepository.buildCreateDiffs(deviceName, model, manufacturer, locationAddress)
    });
  }

  static appendDeleteSubmission(device: DeviceSummary, reason: string, requestId: string, submittedAt: string,
    applicantName: string): void {
    LocalDeviceChangeRequestRepository.requests.unshift({
      id: requestId,
      type: DeviceArchiveReviewRequestType.Delete,
      deviceId: device.id,
      deviceCode: device.deviceCode,
      deviceName: device.name,
      applicantName,
      reason,
      status: DeviceArchiveChangeRequestStatus.PendingReview,
      submittedAt,
      changes: LocalDeviceChangeRequestRepository.buildDeleteDiffs(device)
    });
  }

  static listPending(): DeviceArchiveReviewItem[] {
    return LocalDeviceChangeRequestRepository.requests
      .filter((item: DeviceArchiveReviewItem) => item.status === DeviceArchiveChangeRequestStatus.PendingReview)
      .map((item: DeviceArchiveReviewItem) => LocalDeviceChangeRequestRepository.cloneItem(item));
  }

  static getPendingCount(): number {
    return LocalDeviceChangeRequestRepository.requests
      .filter((item: DeviceArchiveReviewItem) => item.status === DeviceArchiveChangeRequestStatus.PendingReview)
      .length;
  }

  static hasPendingByDeviceCode(deviceCode: string): boolean {
    const normalizedDeviceCode = deviceCode.trim().toUpperCase();
    return LocalDeviceChangeRequestRepository.requests.some((item: DeviceArchiveReviewItem) => {
      return item.status === DeviceArchiveChangeRequestStatus.PendingReview &&
        item.deviceCode.trim().toUpperCase() === normalizedDeviceCode;
    });
  }

  static review(requestId: string, decision: DeviceArchiveReviewDecision, reviewComment: string,
    reviewedAt: string): DeviceArchiveReviewResult | undefined {
    const request = LocalDeviceChangeRequestRepository.requests.find((item: DeviceArchiveReviewItem) => item.id === requestId);
    if (request === undefined || request.status !== DeviceArchiveChangeRequestStatus.PendingReview) {
      return undefined;
    }

    const normalizedReviewedAt = reviewedAt.trim().length === 0 ?
      LocalDeviceChangeRequestRepository.formatDateTime(new Date()) : reviewedAt.trim();
    if (decision === DeviceArchiveReviewDecision.Approved) {
      const freezeUntil = new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString();
      request.status = DeviceArchiveChangeRequestStatus.Approved;
      LocalDeviceChangeRequestRepository.applyApprovedArchiveRequest(request, freezeUntil);
      LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '档案审核通过', request.deviceCode,
        LocalDeviceChangeRequestRepository.formatReviewDescription(reviewComment, true),
        SessionStore.getCurrentOperatorName());
      const result: DeviceArchiveReviewResult = {
        id: request.id,
        status: request.status,
        reviewedAt: normalizedReviewedAt
      };
      if (request.type === DeviceArchiveReviewRequestType.Update) {
        result.freezeUntil = freezeUntil;
      }

      return result;
    }

    request.status = DeviceArchiveChangeRequestStatus.Rejected;
    if (request.type !== DeviceArchiveReviewRequestType.Create) {
      LocalDeviceArchiveRepository.releaseChangeLock(request.deviceCode);
    }
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '档案审核驳回', request.deviceCode,
      LocalDeviceChangeRequestRepository.formatReviewDescription(reviewComment, false),
      SessionStore.getCurrentOperatorName());
    return {
      id: request.id,
      status: request.status,
      reviewedAt: normalizedReviewedAt
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

  private static buildCreateDiffs(deviceName: string, model: string, manufacturer: string,
    locationAddress: string): DeviceArchiveChangeFieldDiff[] {
    const diffs: DeviceArchiveChangeFieldDiff[] = [];
    LocalDeviceChangeRequestRepository.appendCreatedValue(diffs, 'name', '设备名称', deviceName);
    LocalDeviceChangeRequestRepository.appendCreatedValue(diffs, 'model', '设备型号', model);
    LocalDeviceChangeRequestRepository.appendCreatedValue(diffs, 'manufacturer', '生产厂商', manufacturer);
    LocalDeviceChangeRequestRepository.appendCreatedValue(diffs, 'location.address', '设备位置', locationAddress);
    return diffs;
  }

  private static buildDeleteDiffs(device: DeviceSummary): DeviceArchiveChangeFieldDiff[] {
    return [
      {
        field: 'name',
        label: '设备名称',
        oldValue: device.name,
        newValue: '-'
      },
      {
        field: 'model',
        label: '设备型号',
        oldValue: device.model,
        newValue: '-'
      },
      {
        field: 'manufacturer',
        label: '生产厂商',
        oldValue: device.manufacturer,
        newValue: '-'
      },
      {
        field: 'location.address',
        label: '设备位置',
        oldValue: device.location.address,
        newValue: '-'
      }
    ];
  }

  private static appendCreatedValue(diffs: DeviceArchiveChangeFieldDiff[], field: string, label: string,
    value: string): void {
    const normalizedValue = value.trim();
    if (normalizedValue.length === 0) {
      return;
    }

    diffs.push({
      field,
      label,
      oldValue: '-',
      newValue: normalizedValue
    });
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
      type: item.type,
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

  private static applyApprovedArchiveRequest(request: DeviceArchiveReviewItem, freezeUntil: string): void {
    if (request.type === DeviceArchiveReviewRequestType.Create) {
      LocalDeviceArchiveRepository.createFromReview(request.deviceCode, request.changes);
      return;
    }

    if (request.type === DeviceArchiveReviewRequestType.Delete) {
      LocalDeviceArchiveRepository.deleteByCode(request.deviceCode);
      return;
    }

    LocalDeviceArchiveRepository.applyApprovedChange(request.deviceCode, request.changes, freezeUntil);
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
