import {
  OperationRecordListResult,
  OperationRecordStatus,
  OperationRecordSummary,
  OperationRecordType
} from '../models/OperationRecordModels';

const LOCAL_OPERATION_SEEDS: OperationRecordSummary[] = [
  {
    id: 'local-operation-0001',
    type: OperationRecordType.DeviceVerification,
    title: '提交状态核验',
    targetNo: 'RDVP-DEVICE-0001',
    operatorName: '本地用户',
    occurredAt: '2026-05-29 09:20',
    status: OperationRecordStatus.Success,
    description: '记录设备现场运行状态'
  },
  {
    id: 'local-operation-0002',
    type: OperationRecordType.FaultReport,
    title: '提交故障报告',
    targetNo: 'RDF-LOCAL-0001',
    operatorName: '本地用户',
    occurredAt: '2026-05-29 09:40',
    status: OperationRecordStatus.Success,
    description: '故障进入待接取状态'
  }
];

export class LocalOperationRecordRepository {
  private static records: OperationRecordSummary[] = LOCAL_OPERATION_SEEDS.map((item: OperationRecordSummary) => {
    return LocalOperationRecordRepository.cloneRecord(item);
  });
  private static sequence: number = 100;

  static append(type: OperationRecordType, title: string, targetNo: string, description: string,
    operatorName: string = '本地用户', status: OperationRecordStatus = OperationRecordStatus.Success): OperationRecordSummary {
    const sequenceText = LocalOperationRecordRepository.nextSequenceText();
    const record: OperationRecordSummary = {
      id: `local-operation-${sequenceText}`,
      type,
      title,
      targetNo: targetNo.length > 0 ? targetNo : '-',
      operatorName: operatorName.length > 0 ? operatorName : '本地用户',
      occurredAt: LocalOperationRecordRepository.formatDateTime(new Date()),
      status,
      description
    };

    LocalOperationRecordRepository.records.unshift(record);
    return LocalOperationRecordRepository.cloneRecord(record);
  }

  static queryRecentRecords(): OperationRecordListResult {
    const items = LocalOperationRecordRepository.records.map((item: OperationRecordSummary) => {
      return LocalOperationRecordRepository.cloneRecord(item);
    });

    return {
      items,
      total: items.length
    };
  }

  private static cloneRecord(item: OperationRecordSummary): OperationRecordSummary {
    return {
      id: item.id,
      type: item.type,
      title: item.title,
      targetNo: item.targetNo,
      operatorName: item.operatorName,
      occurredAt: item.occurredAt,
      status: item.status,
      description: item.description
    };
  }

  private static nextSequenceText(): string {
    LocalOperationRecordRepository.sequence += 1;
    return `${LocalOperationRecordRepository.sequence}`;
  }

  private static formatDateTime(value: Date): string {
    return `${value.getFullYear()}-${LocalOperationRecordRepository.pad2(value.getMonth() + 1)}-${LocalOperationRecordRepository.pad2(value.getDate())} ${LocalOperationRecordRepository.pad2(value.getHours())}:${LocalOperationRecordRepository.pad2(value.getMinutes())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
