export enum LogCategory {
  ArchiveOperation = 'ARCHIVE_OPERATION',
  ArchiveReview = 'ARCHIVE_REVIEW',
  OperationsOperation = 'OPERATIONS_OPERATION',
  OperationsReview = 'OPERATIONS_REVIEW'
}

export interface LogItem {
  id: string;
  category: LogCategory;
  type: string;
  typeLabel: string;
  deviceCode: string;
  taskNo: string;
  operatorName: string;
  occurredAt: string;
  status: string;
  statusLabel: string;
  description?: string;
}

export interface LogQueryFilter {
  category: LogCategory;
  type: string;
  keyword: string;
  startDate?: string;
  endDate?: string;
  page: number;
  pageSize: number;
}

export interface LogListResult {
  items: LogItem[];
  total: number;
}
