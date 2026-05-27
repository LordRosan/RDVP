export enum WorkbenchActionId {
  DeviceCodeSearch = 'DEVICE_CODE_SEARCH',
  QrScan = 'QR_SCAN',
  DeviceVerification = 'DEVICE_VERIFICATION',
  FaultReport = 'FAULT_REPORT',
  AvailableRepairTask = 'AVAILABLE_REPAIR_TASK',
  MyRepairTask = 'MY_REPAIR_TASK',
  ReinspectionTask = 'REINSPECTION_TASK',
  OperationRecord = 'OPERATION_RECORD'
}

export interface WorkbenchAction {
  id: WorkbenchActionId;
  title: string;
  summary: string;
  mark: string;
  tone: string;
}

export interface WorkbenchMetric {
  id: string;
  label: string;
  value: string;
  status: string;
  tone: string;
}

export interface WorkbenchStatusItem {
  id: string;
  name: string;
  value: string;
  tone: string;
}

