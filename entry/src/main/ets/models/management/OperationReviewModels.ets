export enum OperationReviewDecision {
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export enum OperationReviewRequestType {
  RepairReport = 'REPAIR_REPORT',
  ReinspectionRecord = 'REINSPECTION_RECORD'
}

export enum OperationReviewRequestStatus {
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export interface OperationReviewItem {
  id: string;
  type: OperationReviewRequestType;
  targetId: string;
  targetNo: string;
  faultReportId: string;
  deviceId: string;
  deviceCode: string;
  deviceName: string;
  applicantId: string;
  applicantName: string;
  summary: string;
  status: OperationReviewRequestStatus;
  submittedAt: string;
  reviewerId?: string;
  reviewComment?: string;
  reviewedAt?: string;
}

export interface OperationReviewListResult {
  items: OperationReviewItem[];
  total: number;
}

export interface OperationReviewForm {
  requestId: string;
  decision: OperationReviewDecision;
  reviewedAt: string;
  reviewComment: string;
}

export interface OperationReviewResult {
  id: string;
  status: OperationReviewRequestStatus;
  reviewedAt: string;
}
