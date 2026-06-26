export enum RecordCategory {
  Archive = 'ARCHIVE',
  Operations = 'OPERATIONS',
  Review = 'REVIEW'
}

export interface RecordItem {
  id: string;
  category: RecordCategory;
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

export interface RecordQueryFilter {
  category: RecordCategory;
  type: string;
  keyword: string;
  startDate?: string;
  endDate?: string;
  page: number;
  pageSize: number;
}

export interface RecordListResult {
  items: RecordItem[];
  total: number;
}
