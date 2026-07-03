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
public class InMemoryArchiveRequestRepository implements ArchiveRequestRepository {

    private final Map<String, ArchiveRequest> requestsById = new ConcurrentHashMap<>();
    private final InMemoryArchiveRepository archiveRepository;

    public InMemoryArchiveRequestRepository(InMemoryArchiveRepository archiveRepository) {
        this.archiveRepository = archiveRepository;
        requestsById.put(
                "DCR-LOCAL-0002",
                new ArchiveRequest(
                        "DCR-LOCAL-0002",
                        ArchiveRequestType.UPDATE,
                        "device-local-0002",
                        "RDVP-DEVICE-0002",
                        "输送线B-02",
                        "usr-archivist",
                        null,
                        ArchiveRequestStatus.PENDING_REVIEW,
                        "现场标识位置需要修正档案。",
                        Map.of(
                                "location.address",
                                new ArchiveFieldChange("二号厂房包装区", "二号厂房包装区A段")),
                        OffsetDateTime.parse("2026-05-29T10:10:00Z"),
                        OffsetDateTime.parse("2026-05-29T10:10:00Z"),
                        null,
                        null,
                        null,
                        null));
    }

    @Override
    public Optional<ArchiveRequest> findById(String id) {
        return Optional.ofNullable(requestsById.get(id));
    }

    @Override
    public ArchiveRequestPage list(ArchiveRequestQuery query) {
        var items = requestsById.values()
                .stream()
                .filter(item -> query.status() == null || item.status() == query.status())
                .filter(item -> query.deviceCode() == null || item.deviceCode().equals(query.deviceCode()))
                .filter(item -> query.applicantId() == null || item.applicantId().equals(query.applicantId()))
                .filter(item -> query.type() == null || query.type().isBlank() ||
                        item.type().name().equalsIgnoreCase(query.type()))
                .sorted(Comparator.comparing(ArchiveRequest::createdAt).reversed())
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
        return new ArchiveRequestPage(items, total);
    }

    @Override
    public long countAll() {
        return requestsById.size();
    }

    @Override
    public long countPendingReview() {
        return requestsById.values()
                .stream()
                .filter(item -> item.status() == ArchiveRequestStatus.PENDING_REVIEW)
                .count();
    }

    @Override
    public long countApprovedByType(ArchiveRequestType type) {
        return requestsById.values()
                .stream()
                .filter(item -> item.status() == ArchiveRequestStatus.APPROVED)
                .filter(item -> item.type() == type)
                .count();
    }

    @Override
    public long countReviewed() {
        return requestsById.values()
                .stream()
                .filter(item -> item.status() == ArchiveRequestStatus.APPROVED ||
                        item.status() == ArchiveRequestStatus.REJECTED)
                .count();
    }

    @Override
    public boolean hasPendingByDeviceId(String deviceId) {
        return requestsById.values()
                .stream()
                .anyMatch(item -> deviceId.equals(item.deviceId()) && item.status() == ArchiveRequestStatus.PENDING_REVIEW);
    }

    @Override
    public boolean hasPendingByTargetDeviceCode(String deviceCode) {
        return requestsById.values()
                .stream()
                .anyMatch(item -> deviceCode.equals(item.deviceCode()) && item.status() == ArchiveRequestStatus.PENDING_REVIEW);
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now) {
        Optional<String> deviceCode = archiveRepository.findById(deviceId).map(Archive::deviceCode);
        Optional<OffsetDateTime> requestFreeze = requestsById.values()
                .stream()
                .filter(item -> deviceId.equals(item.deviceId()) ||
                        deviceCode.filter(code -> code.equals(item.deviceCode())).isPresent())
                .map(ArchiveRequest::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now))
                .max(Comparator.naturalOrder());
        Optional<OffsetDateTime> archiveFreeze = archiveRepository.findById(deviceId)
                .map(Archive::archiveRequestState)
                .map(Archive.ArchiveRequestState::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now));
        return requestFreeze.isPresent() ? requestFreeze : archiveFreeze;
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntilByTargetDeviceCode(String deviceCode, OffsetDateTime now) {
        return requestsById.values()
                .stream()
                .filter(item -> deviceCode.equals(item.deviceCode()))
                .map(ArchiveRequest::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now))
                .max(Comparator.naturalOrder());
    }

    @Override
    public void create(ArchiveRequestCreate request) {
        Archive device = request.deviceId() == null
                ? null
                : archiveRepository.findById(request.deviceId()).orElseThrow();
        ArchiveRequest item = new ArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.targetDeviceCode(),
                resolveDeviceName(device, request.changes()),
                request.applicantId(),
                null,
                ArchiveRequestStatus.PENDING_REVIEW,
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
            ArchiveUpdate archiveUpdate) {
        ArchiveRequest request = requestsById.get(requestId);
        if (request == null || request.status() != ArchiveRequestStatus.PENDING_REVIEW) {
            return false;
        }

        requestsById.put(requestId, new ArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                ArchiveRequestStatus.APPROVED,
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
        ArchiveRequest request = requestsById.get(requestId);
        if (request == null || request.status() != ArchiveRequestStatus.PENDING_REVIEW) {
            return false;
        }

        requestsById.put(requestId, new ArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                ArchiveRequestStatus.APPROVED,
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
        ArchiveRequest request = requestsById.get(requestId);
        if (request == null || request.status() != ArchiveRequestStatus.PENDING_REVIEW) {
            return false;
        }

        requestsById.put(requestId, new ArchiveRequest(
                request.id(),
                request.type(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                ArchiveRequestStatus.REJECTED,
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

    private String resolveDeviceName(Archive device, Map<String, ArchiveFieldChange> changes) {
        if (device != null) {
            return device.name();
        }

        ArchiveFieldChange name = changes.get("name");
        if (name != null && name.newValue() != null && !name.newValue().isBlank()) {
            return name.newValue();
        }

        return "-";
    }
}
