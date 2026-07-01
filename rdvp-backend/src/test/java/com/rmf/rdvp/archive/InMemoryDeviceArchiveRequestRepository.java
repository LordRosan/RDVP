package com.rmf.rdvp.archive;

import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryDeviceArchiveRequestRepository implements DeviceArchiveRequestRepository {

    private final Map<String, DeviceArchiveRequest> requestsById = new ConcurrentHashMap<>();
    private final InMemoryDeviceArchiveRepository archiveRepository;

    public InMemoryDeviceArchiveRequestRepository(InMemoryDeviceArchiveRepository archiveRepository) {
        this.archiveRepository = archiveRepository;
        requestsById.put(
                "DCR-LOCAL-0002",
                new DeviceArchiveRequest(
                        "DCR-LOCAL-0002",
                        DeviceArchiveRequestType.UPDATE,
                        "device-local-0002",
                        "RDVP-DEVICE-0002",
                        "输送线B-02",
                        "usr-archivist",
                        null,
                        DeviceArchiveRequestStatus.PENDING_REVIEW,
                        "现场标识位置需要修正档案。",
                        Map.of(
                                "location.address",
                                new DeviceArchiveFieldChange("二号厂房包装区", "二号厂房包装区A段")),
                        OffsetDateTime.parse("2026-05-29T10:10:00Z"),
                        OffsetDateTime.parse("2026-05-29T10:10:00Z"),
                        null,
                        null,
                        null,
                        null));
    }

    @Override
    public Optional<DeviceArchiveRequest> findById(String id) {
        return Optional.ofNullable(requestsById.get(id));
    }

    @Override
    public DeviceArchiveRequestPage list(DeviceArchiveRequestQuery query) {
        var items = requestsById.values()
                .stream()
                .filter(item -> query.status() == null || item.status() == query.status())
                .filter(item -> query.deviceCode() == null || item.deviceCode().equals(query.deviceCode()))
                .filter(item -> query.applicantId() == null || item.applicantId().equals(query.applicantId()))
                .filter(item -> query.type() == null || query.type().isBlank() ||
                        item.type().name().equalsIgnoreCase(query.type()))
                .sorted(Comparator.comparing(DeviceArchiveRequest::createdAt).reversed())
                .skip((long) (query.page() - 1) * query.pageSize())
                .limit(query.pageSize())
                .toList();
        long total = requestsById.values()
                .stream()
                .filter(item -> query.status() == null || item.status() == query.status())
                .filter(item -> query.deviceCode() == null || item.deviceCode().equals(query.deviceCode()))
                .filter(item -> query.applicantId() == null || item.applicantId().equals(query.applicantId()))
                .filter(item -> query.type() == null || query.type().isBlank() ||
                        item.type().name().equalsIgnoreCase(query.type()))
                .count();
        return new DeviceArchiveRequestPage(items, total);
    }

    @Override
    public long countAll() {
        return requestsById.size();
    }

    @Override
    public long countPendingReview() {
        return requestsById.values()
                .stream()
                .filter(item -> item.status() == DeviceArchiveRequestStatus.PENDING_REVIEW)
                .count();
    }

    @Override
    public long countApprovedByType(DeviceArchiveRequestType type) {
        return requestsById.values()
                .stream()
                .filter(item -> item.status() == DeviceArchiveRequestStatus.APPROVED)
                .filter(item -> item.type() == type)
                .count();
    }

    @Override
    public long countReviewed() {
        return requestsById.values()
                .stream()
                .filter(item -> item.status() == DeviceArchiveRequestStatus.APPROVED ||
                        item.status() == DeviceArchiveRequestStatus.REJECTED)
                .count();
    }

    @Override
    public boolean hasPendingByDeviceId(String deviceId) {
        return requestsById.values()
                .stream()
                .anyMatch(item -> deviceId.equals(item.deviceId()) && item.status() == DeviceArchiveRequestStatus.PENDING_REVIEW);
    }

    @Override
    public boolean hasPendingByTargetDeviceCode(String deviceCode) {
        return requestsById.values()
                .stream()
                .anyMatch(item -> deviceCode.equals(item.deviceCode()) && item.status() == DeviceArchiveRequestStatus.PENDING_REVIEW);
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now) {
        Optional<String> deviceCode = archiveRepository.findById(deviceId).map(DeviceArchive::deviceCode);
        Optional<OffsetDateTime> requestFreeze = requestsById.values()
                .stream()
                .filter(item -> deviceId.equals(item.deviceId()) ||
                        deviceCode.filter(code -> code.equals(item.deviceCode())).isPresent())
                .map(DeviceArchiveRequest::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now))
                .max(Comparator.naturalOrder());
        Optional<OffsetDateTime> archiveFreeze = archiveRepository.findById(deviceId)
                .map(DeviceArchive::archiveRequestState)
                .map(DeviceArchive.ArchiveRequestState::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now));
        return requestFreeze.isPresent() ? requestFreeze : archiveFreeze;
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntilByTargetDeviceCode(String deviceCode, OffsetDateTime now) {
        return requestsById.values()
                .stream()
                .filter(item -> deviceCode.equals(item.deviceCode()))
                .map(DeviceArchiveRequest::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now))
                .max(Comparator.naturalOrder());
    }

    @Override
    public void create(DeviceArchiveRequestCreate request) {
        DeviceArchive device = request.deviceId() == null
                ? null
                : archiveRepository.findById(request.deviceId()).orElseThrow();
        DeviceArchiveRequest item = new DeviceArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.targetDeviceCode(),
                resolveDeviceName(device, request.changes()),
                request.applicantId(),
                null,
                DeviceArchiveRequestStatus.PENDING_REVIEW,
                request.reason(),
                request.changes(),
                request.initiatedAt(),
                request.createdAt(),
                null,
                null,
                null,
                null);
        requestsById.put(request.id(), item);
        if (request.deviceId() != null) {
            archiveRepository.markPending(request.deviceId(), request.id());
        }
    }

    @Override
    public boolean applyApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil,
            DeviceArchiveUpdate archiveUpdate) {
        DeviceArchiveRequest request = requestsById.get(requestId);
        if (request == null || request.status() != DeviceArchiveRequestStatus.PENDING_REVIEW) {
            return false;
        }

        requestsById.put(requestId, new DeviceArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                DeviceArchiveRequestStatus.APPROVED,
                request.reason(),
                request.changes(),
                request.initiatedAt(),
                request.createdAt(),
                reviewerId,
                reviewComment,
                reviewedAt,
                freezeUntil));
        archiveRepository.applyUpdate(archiveUpdate, freezeUntil);
        return true;
    }

    @Override
    public boolean markApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil) {
        DeviceArchiveRequest request = requestsById.get(requestId);
        if (request == null || request.status() != DeviceArchiveRequestStatus.PENDING_REVIEW) {
            return false;
        }

        requestsById.put(requestId, new DeviceArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                DeviceArchiveRequestStatus.APPROVED,
                request.reason(),
                request.changes(),
                request.initiatedAt(),
                request.createdAt(),
                reviewerId,
                reviewComment,
                reviewedAt,
                freezeUntil));
        if (request.deviceId() != null) {
            archiveRepository.clearPending(request.deviceId());
        } else if (freezeUntil != null) {
            archiveRepository.freezeByCode(request.deviceCode(), freezeUntil);
        }
        return true;
    }

    @Override
    public boolean applyRejectedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil) {
        DeviceArchiveRequest request = requestsById.get(requestId);
        if (request == null || request.status() != DeviceArchiveRequestStatus.PENDING_REVIEW) {
            return false;
        }

        requestsById.put(requestId, new DeviceArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                DeviceArchiveRequestStatus.REJECTED,
                request.reason(),
                request.changes(),
                request.initiatedAt(),
                request.createdAt(),
                reviewerId,
                reviewComment,
                reviewedAt,
                freezeUntil));
        if (request.deviceId() != null) {
            archiveRepository.freeze(request.deviceId(), freezeUntil);
        }
        return true;
    }

    private String resolveDeviceName(DeviceArchive device, Map<String, DeviceArchiveFieldChange> changes) {
        if (device != null) {
            return device.name();
        }

        DeviceArchiveFieldChange name = changes.get("name");
        if (name != null && name.newValue() != null && !name.newValue().isBlank()) {
            return name.newValue();
        }

        return "-";
    }
}
