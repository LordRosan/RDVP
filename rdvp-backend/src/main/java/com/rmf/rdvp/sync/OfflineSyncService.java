package com.rmf.rdvp.sync;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rmf.rdvp.archive.DeviceArchive;
import com.rmf.rdvp.archive.DeviceArchiveRepository;
import com.rmf.rdvp.archive.DeviceArchiveService;
import com.rmf.rdvp.archive.DeviceChangeRequest;
import com.rmf.rdvp.archive.DeviceChangeRequestService;
import com.rmf.rdvp.archive.DeviceChangeRequestType;
import com.rmf.rdvp.archive.DeviceChangeValue;
import com.rmf.rdvp.archive.DeviceVerificationRecord;
import com.rmf.rdvp.archive.DeviceVerificationResult;
import com.rmf.rdvp.audit.AuditAction;
import com.rmf.rdvp.audit.AuditLogService;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticationService;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.operations.DeviceVerificationFaultReportResult;
import com.rmf.rdvp.operations.FaultReportRecord;
import com.rmf.rdvp.operations.FaultSeverity;
import com.rmf.rdvp.operations.FaultType;
import com.rmf.rdvp.operations.OperationsService;

@Service
public class OfflineSyncService {

    private static final int MAX_BATCH_RECORDS = 20;
    private static final int MAX_PAYLOAD_LENGTH = 8_000;
    private static final int MAX_ERROR_MESSAGE_LENGTH = 300;
    private static final int DEFAULT_AUDIT_PAGE_SIZE = 20;
    private static final int MAX_AUDIT_PAGE_SIZE = 100;
    private static final int MAX_AUDIT_PAGE_NUMBER = 10_000;
    private static final Duration MAX_CREATED_OFFLINE_FUTURE_SKEW = Duration.ofMinutes(5);
    private static final Pattern CLIENT_ID_PATTERN = Pattern.compile("^[A-Za-z0-9._-]{1,128}$");
    private static final String PAYLOAD_HASH_ALGORITHM = "SHA-256";

    private final OfflineSyncRepository offlineSyncRepository;
    private final DeviceArchiveRepository archiveRepository;
    private final DeviceArchiveService archiveService;
    private final DeviceChangeRequestService changeRequestService;
    private final OperationsService operationsService;
    private final AuthenticationService authenticationService;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    public OfflineSyncService(
            OfflineSyncRepository offlineSyncRepository,
            DeviceArchiveRepository archiveRepository,
            DeviceArchiveService archiveService,
            DeviceChangeRequestService changeRequestService,
            OperationsService operationsService,
            AuthenticationService authenticationService,
            AuditLogService auditLogService,
            ObjectMapper objectMapper) {
        this.offlineSyncRepository = offlineSyncRepository;
        this.archiveRepository = archiveRepository;
        this.archiveService = archiveService;
        this.changeRequestService = changeRequestService;
        this.operationsService = operationsService;
        this.authenticationService = authenticationService;
        this.auditLogService = auditLogService;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public OfflineSyncBatchResult synchronize(
            String clientBatchId,
            List<OfflineSyncRecordInput> records,
            AuthenticatedUser operator) {
        String normalizedBatchId = normalizeClientId(
                clientBatchId,
                "clientBatchId",
                ErrorCode.OFFLINE_SYNC_BATCH_INVALID);
        List<OfflineSyncRecordInput> normalizedRecords = normalizeRecords(records);
        return offlineSyncRepository.findBatchResult(operator.id(), normalizedBatchId)
                .orElseGet(() -> processNewBatch(normalizedBatchId, normalizedRecords, operator));
    }

    private OfflineSyncBatchResult processNewBatch(
            String clientBatchId,
            List<OfflineSyncRecordInput> records,
            AuthenticatedUser operator) {
        OffsetDateTime now = now();
        List<OfflineSyncRecordCreate> creates = new ArrayList<>();
        List<OfflineSyncRecordResult> results = new ArrayList<>();

        for (OfflineSyncRecordInput record : records) {
            PreparedPayload preparedPayload = preparePayload(record);
            OfflineSyncRecordResult createdAtError = validateCreatedOfflineAt(record, now);
            OfflineSyncRecordResult result = createdAtError != null
                    ? createdAtError
                    : preparedPayload.errorResult() == null
                            ? resolveRecordResult(record, operator, preparedPayload)
                            : preparedPayload.errorResult();
            results.add(result);
            creates.add(toCreate(record, preparedPayload, result, now));
        }

        OfflineSyncBatchStatus status = resolveBatchStatus(results);
        OfflineSyncBatchCreate batch = new OfflineSyncBatchCreate(
                "offline-batch-" + UUID.randomUUID(),
                clientBatchId,
                operator.id(),
                status,
                now,
                now,
                creates);
        offlineSyncRepository.saveBatch(batch);
        recordAudit(batch, results, operator);
        return new OfflineSyncBatchResult(clientBatchId, status, List.copyOf(results));
    }

    public OfflineSyncProcessingPage listProcessingRecords(int page, int pageSize, AuthenticatedUser operator) {
        requirePermission(operator, PermissionCode.MGMT_AUDIT_LOG_READ);
        return offlineSyncRepository.listProcessingRecords(
                normalizeAuditPage(page),
                normalizeAuditPageSize(pageSize));
    }

    private OfflineSyncRecordResult resolveRecordResult(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator,
            PreparedPayload preparedPayload) {
        var existingRecord = offlineSyncRepository.findRecord(operator.id(), record.clientRecordId());
        if (existingRecord.isPresent()) {
            OfflineSyncStoredRecord storedRecord = existingRecord.get();
            if (storedRecord.recordType() != record.recordType()
                    || !storedRecord.payloadHash().equals(preparedPayload.payloadHash())) {
                return failed(
                        record,
                        ErrorCode.OFFLINE_RECORD_CONFLICT,
                        "clientRecordId has already been used for a different offline record.");
            }

            return storedRecord.result();
        }

        return processRecord(record, operator);
    }

    private OfflineSyncRecordResult processRecord(OfflineSyncRecordInput record, AuthenticatedUser operator) {
        try {
            return switch (record.recordType()) {
                case FAULT_REPORT_CREATE -> processFaultReport(record, operator);
                case DEVICE_VERIFICATION_CREATE -> processDeviceVerification(record, operator);
                case DEVICE_VERIFICATION_FAULT_REPORT_CREATE -> processDeviceVerificationFaultReport(record, operator);
                case DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE -> processDeviceArchiveUpdateRequest(record, operator);
                case DEVICE_ARCHIVE_CREATE_REQUEST_CREATE -> processDeviceArchiveCreateRequest(record, operator);
                case DEVICE_ARCHIVE_DELETE_REQUEST_CREATE -> processDeviceArchiveDeleteRequest(record, operator);
            };
        } catch (BusinessException exception) {
            return failed(record, exception.getErrorCode(), exception.getMessage());
        } catch (JsonProcessingException exception) {
            return failed(record, ErrorCode.OFFLINE_SYNC_RECORD_INVALID, "payload is invalid.");
        } catch (RuntimeException exception) {
            return failed(record, ErrorCode.INTERNAL_ERROR, ErrorCode.INTERNAL_ERROR.defaultMessage());
        }
    }

    private OfflineSyncRecordResult processFaultReport(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator) throws JsonProcessingException {
        requirePermission(operator, PermissionCode.OPS_FAULT_REPORT_CREATE);
        FaultReportPayload payload = readPayload(record.payload(), FaultReportPayload.class);
        FaultReportRecord created = operationsService.createFaultReport(
                payload.deviceCode(),
                parseEnum(FaultType.class, payload.faultType(), "faultType"),
                parseEnum(FaultSeverity.class, payload.severity(), "severity"),
                payload.occurredAt(),
                payload.description(),
                payload.sceneCondition(),
                null,
                null,
                operator);
        return OfflineSyncRecordResult.succeeded(record.clientRecordId(), record.recordType(), created.id());
    }

    private OfflineSyncRecordResult processDeviceVerification(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator) throws JsonProcessingException {
        requirePermission(operator, PermissionCode.OPS_DEVICE_VERIFY);
        DeviceVerificationPayload payload = readPayload(record.payload(), DeviceVerificationPayload.class);
        DeviceArchive device = findDeviceByCode(payload.deviceCode());
        DeviceVerificationRecord created = archiveService.createVerificationRecord(
                device.id(),
                parseEnum(DeviceVerificationResult.class, payload.result(), "result"),
                payload.description(),
                payload.remark(),
                payload.verifiedAt(),
                operator);
        return OfflineSyncRecordResult.succeeded(record.clientRecordId(), record.recordType(), created.id());
    }

    private OfflineSyncRecordResult processDeviceVerificationFaultReport(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator) throws JsonProcessingException {
        requirePermission(operator, PermissionCode.OPS_DEVICE_VERIFY);
        requirePermission(operator, PermissionCode.OPS_FAULT_REPORT_CREATE);
        DeviceVerificationFaultReportPayload payload = readPayload(record.payload(), DeviceVerificationFaultReportPayload.class);
        DeviceArchive device = findDeviceByCode(payload.deviceCode());
        DeviceVerificationFaultReportResult created = operationsService.createVerificationWithFaultReport(
                device.id(),
                parseEnum(DeviceVerificationResult.class, payload.result(), "result"),
                payload.description(),
                payload.remark(),
                payload.verifiedAt(),
                parseEnum(FaultType.class, payload.faultType(), "faultType"),
                parseEnum(FaultSeverity.class, payload.severity(), "severity"),
                payload.occurredAt(),
                payload.faultDescription(),
                payload.sceneCondition(),
                null,
                null,
                operator);
        return OfflineSyncRecordResult.succeeded(
                record.clientRecordId(),
                record.recordType(),
                created.verificationRecord().id());
    }

    private OfflineSyncRecordResult processDeviceArchiveUpdateRequest(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator) throws JsonProcessingException {
        requirePermission(operator, PermissionCode.ARCHIVE_CHANGE_REQUEST_CREATE);
        DeviceArchiveUpdateRequestPayload payload = readPayload(record.payload(), DeviceArchiveUpdateRequestPayload.class);
        DeviceChangeRequest created = changeRequestService.create(
                DeviceChangeRequestType.UPDATE,
                payload.deviceId(),
                payload.deviceCode(),
                payload.reason(),
                toChangeMap(payload.changes(), true),
                record.createdOfflineAt(),
                operator);
        return OfflineSyncRecordResult.succeeded(record.clientRecordId(), record.recordType(), created.id());
    }

    private OfflineSyncRecordResult processDeviceArchiveCreateRequest(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator) throws JsonProcessingException {
        requirePermission(operator, PermissionCode.ARCHIVE_DEVICE_CREATE);
        DeviceArchiveCreateRequestPayload payload = readPayload(record.payload(), DeviceArchiveCreateRequestPayload.class);
        DeviceChangeRequest created = changeRequestService.create(
                DeviceChangeRequestType.CREATE,
                null,
                payload.deviceCode(),
                payload.reason(),
                toChangeMap(payload.changes(), false),
                record.createdOfflineAt(),
                operator);
        return OfflineSyncRecordResult.succeeded(record.clientRecordId(), record.recordType(), created.id());
    }

    private OfflineSyncRecordResult processDeviceArchiveDeleteRequest(
            OfflineSyncRecordInput record,
            AuthenticatedUser operator) throws JsonProcessingException {
        requirePermission(operator, PermissionCode.ARCHIVE_DEVICE_DELETE);
        authenticationService.requireRecentPasswordVerification(operator);
        DeviceArchiveDeleteRequestPayload payload = readPayload(record.payload(), DeviceArchiveDeleteRequestPayload.class);
        DeviceChangeRequest created = changeRequestService.create(
                DeviceChangeRequestType.DELETE,
                payload.deviceId(),
                payload.deviceCode(),
                payload.reason(),
                Map.of(),
                record.createdOfflineAt(),
                operator);
        return OfflineSyncRecordResult.succeeded(record.clientRecordId(), record.recordType(), created.id());
    }

    private Map<String, DeviceChangeValue> toChangeMap(List<DeviceArchiveChangeValuePayload> changes, boolean requireOldValue) {
        if (changes == null || changes.isEmpty()) {
            throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
        }

        Map<String, DeviceChangeValue> result = new TreeMap<>();
        for (DeviceArchiveChangeValuePayload change : changes) {
            if (change == null || change.field() == null || change.field().isBlank()) {
                throw new BusinessException(ErrorCode.DEVICE_CHANGE_REQUEST_INVALID);
            }

            if (requireOldValue && change.oldValue() == null) {
                throw new BusinessException(
                        ErrorCode.DEVICE_CHANGE_REQUEST_INVALID,
                        "oldValue is required when updating a device archive.");
            }

            result.put(
                    change.field().trim(),
                    new DeviceChangeValue(change.oldValue(), change.newValue()));
        }

        return Map.copyOf(result);
    }

    private List<OfflineSyncRecordInput> normalizeRecords(List<OfflineSyncRecordInput> records) {
        if (records == null || records.isEmpty() || records.size() > MAX_BATCH_RECORDS) {
            throw new BusinessException(
                    ErrorCode.OFFLINE_SYNC_BATCH_INVALID,
                    "records must contain 1 to %d items.".formatted(MAX_BATCH_RECORDS));
        }

        Set<String> clientRecordIds = new HashSet<>();
        List<OfflineSyncRecordInput> normalizedRecords = new ArrayList<>();
        for (OfflineSyncRecordInput record : records) {
            if (record == null) {
                throw new BusinessException(ErrorCode.OFFLINE_SYNC_RECORD_INVALID, "record is required.");
            }

            String clientRecordId = normalizeClientId(
                    record.clientRecordId(),
                    "clientRecordId",
                    ErrorCode.OFFLINE_SYNC_RECORD_INVALID);
            if (!clientRecordIds.add(clientRecordId)) {
                throw new BusinessException(ErrorCode.OFFLINE_RECORD_DUPLICATED, "clientRecordId is duplicated.");
            }

            if (record.recordType() == null || record.payload() == null || record.createdOfflineAt() == null) {
                throw new BusinessException(ErrorCode.OFFLINE_SYNC_RECORD_INVALID);
            }

            OffsetDateTime createdOfflineAt = record.createdOfflineAt().withOffsetSameInstant(ZoneOffset.UTC);
            normalizedRecords.add(new OfflineSyncRecordInput(
                    clientRecordId,
                    record.recordType(),
                    record.payload(),
                    createdOfflineAt));
        }

        normalizedRecords.sort(Comparator
                .comparing(OfflineSyncRecordInput::createdOfflineAt)
                .thenComparing(OfflineSyncRecordInput::clientRecordId));
        return List.copyOf(normalizedRecords);
    }

    private OfflineSyncRecordResult validateCreatedOfflineAt(
            OfflineSyncRecordInput record,
            OffsetDateTime receivedAt) {
        OffsetDateTime createdOfflineAt = record.createdOfflineAt().withOffsetSameInstant(ZoneOffset.UTC);
        if (!createdOfflineAt.isAfter(receivedAt.plus(MAX_CREATED_OFFLINE_FUTURE_SKEW))) {
            return null;
        }

        return failed(
                record,
                ErrorCode.OFFLINE_SYNC_RECORD_INVALID,
                "createdOfflineAt must not be in the future.");
    }

    private String normalizeClientId(String value, String field, ErrorCode errorCode) {
        String normalized = value == null ? "" : value.trim();
        if (!CLIENT_ID_PATTERN.matcher(normalized).matches()) {
            throw new BusinessException(errorCode, field + " is invalid.");
        }

        return normalized;
    }

    private int normalizeAuditPage(int page) {
        return Math.min(Math.max(page, 1), MAX_AUDIT_PAGE_NUMBER);
    }

    private int normalizeAuditPageSize(int pageSize) {
        if (pageSize <= 0) {
            return DEFAULT_AUDIT_PAGE_SIZE;
        }

        return Math.min(pageSize, MAX_AUDIT_PAGE_SIZE);
    }

    private OfflineSyncRecordCreate toCreate(
            OfflineSyncRecordInput record,
            PreparedPayload preparedPayload,
            OfflineSyncRecordResult result,
            OffsetDateTime now) {
        return new OfflineSyncRecordCreate(
                "offline-record-" + UUID.randomUUID(),
                record.clientRecordId(),
                record.recordType(),
                preparedPayload.payloadJson(),
                preparedPayload.payloadHash(),
                result.status(),
                result.serverRecordId(),
                result.errorCode(),
                result.errorMessage(),
                record.createdOfflineAt(),
                now,
                now);
    }

    private OfflineSyncBatchStatus resolveBatchStatus(List<OfflineSyncRecordResult> results) {
        long successCount = results.stream().filter(OfflineSyncRecordResult::success).count();
        if (successCount == results.size()) {
            return OfflineSyncBatchStatus.COMPLETED;
        }

        return successCount == 0 ? OfflineSyncBatchStatus.FAILED : OfflineSyncBatchStatus.PARTIALLY_FAILED;
    }

    private void recordAudit(
            OfflineSyncBatchCreate batch,
            List<OfflineSyncRecordResult> results,
            AuthenticatedUser operator) {
        long successCount = results.stream().filter(OfflineSyncRecordResult::success).count();
        long failedCount = results.size() - successCount;
        String description = "离线同步批次完成：成功%d项，失败%d项。".formatted(successCount, failedCount);
        if (failedCount == 0) {
            auditLogService.recordSuccess(AuditAction.OFFLINE_SYNC, batch.id(), batch.clientBatchId(), operator, description);
            return;
        }

        auditLogService.recordFailure(AuditAction.OFFLINE_SYNC, batch.id(), batch.clientBatchId(), operator, description);
    }

    private void requirePermission(AuthenticatedUser operator, PermissionCode permission) {
        if (operator == null || !operator.permissions().contains(permission)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private DeviceArchive findDeviceByCode(String deviceCode) {
        return archiveRepository.findByCode(deviceCode == null ? "" : deviceCode.trim().toUpperCase())
                .orElseThrow(() -> new BusinessException(ErrorCode.DEVICE_NOT_FOUND));
    }

    private <T> T readPayload(Object payload, Class<T> type) throws JsonProcessingException {
        return objectMapper.readValue(serializePayload(payload), type);
    }

    private <T extends Enum<T>> T parseEnum(Class<T> enumType, String value, String field) {
        try {
            return Enum.valueOf(enumType, value.trim().toUpperCase());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, field + " is invalid.");
        }
    }

    private String serializePayload(Object payload) throws JsonProcessingException {
        return objectMapper.writeValueAsString(canonicalizePayload(payload == null ? Map.of() : payload));
    }

    private Object canonicalizePayload(Object payload) {
        if (payload instanceof Map<?, ?> map) {
            Map<String, Object> sorted = new TreeMap<>();
            map.forEach((key, value) -> sorted.put(String.valueOf(key), canonicalizePayload(value)));
            return sorted;
        }

        if (payload instanceof List<?> list) {
            return list.stream().map(this::canonicalizePayload).toList();
        }

        return payload;
    }

    private PreparedPayload preparePayload(OfflineSyncRecordInput record) {
        try {
            String payloadJson = serializePayload(record.payload());
            if (payloadJson.length() > MAX_PAYLOAD_LENGTH) {
                String fallbackJson = "{}";
                return PreparedPayload.failed(
                        fallbackJson,
                        hashPayloadJson(fallbackJson),
                        failed(record, ErrorCode.OFFLINE_SYNC_RECORD_INVALID, "payload is too large."));
            }

            return PreparedPayload.valid(payloadJson, hashPayloadJson(payloadJson));
        } catch (JsonProcessingException exception) {
            String fallbackJson = "{}";
            return PreparedPayload.failed(
                    fallbackJson,
                    hashPayloadJson(fallbackJson),
                    failed(record, ErrorCode.OFFLINE_SYNC_RECORD_INVALID, "payload is invalid."));
        }
    }

    private String hashPayloadJson(String payloadJson) {
        try {
            MessageDigest digest = MessageDigest.getInstance(PAYLOAD_HASH_ALGORITHM);
            return HexFormat.of().formatHex(digest.digest(payloadJson.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private OfflineSyncRecordResult failed(
            OfflineSyncRecordInput record,
            ErrorCode errorCode,
            String message) {
        return OfflineSyncRecordResult.failed(
                record.clientRecordId(),
                record.recordType(),
                errorCode.code(),
                normalizeErrorMessage(message, errorCode.defaultMessage()));
    }

    private String normalizeErrorMessage(String value, String fallback) {
        String normalized = value == null || value.isBlank() ? fallback : value.trim();
        return normalized.length() <= MAX_ERROR_MESSAGE_LENGTH
                ? normalized
                : normalized.substring(0, MAX_ERROR_MESSAGE_LENGTH);
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }

    private record FaultReportPayload(
            String deviceCode,
            String faultType,
            String severity,
            String occurredAt,
            String description,
            String sceneCondition) {
    }

    private record DeviceVerificationPayload(
            String deviceCode,
            String result,
            String description,
            String remark,
            String verifiedAt) {
    }

    private record DeviceVerificationFaultReportPayload(
            String deviceCode,
            String result,
            String description,
            String remark,
            String verifiedAt,
            String faultType,
            String severity,
            String occurredAt,
            String faultDescription,
            String sceneCondition) {
    }

    private record DeviceArchiveChangeValuePayload(
            String field,
            String oldValue,
            String newValue) {
    }

    private record DeviceArchiveUpdateRequestPayload(
            String deviceId,
            String deviceCode,
            String reason,
            List<DeviceArchiveChangeValuePayload> changes) {
    }

    private record DeviceArchiveCreateRequestPayload(
            String deviceCode,
            String reason,
            List<DeviceArchiveChangeValuePayload> changes) {
    }

    private record DeviceArchiveDeleteRequestPayload(
            String deviceId,
            String deviceCode,
            String reason) {
    }

    private record PreparedPayload(
            String payloadJson,
            String payloadHash,
            OfflineSyncRecordResult errorResult) {

        private static PreparedPayload valid(String payloadJson, String payloadHash) {
            return new PreparedPayload(payloadJson, payloadHash, null);
        }

        private static PreparedPayload failed(
                String payloadJson,
                String payloadHash,
                OfflineSyncRecordResult errorResult) {
            return new PreparedPayload(payloadJson, payloadHash, errorResult);
        }
    }
}
