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
public class InMemoryDeviceChangeRequestRepository implements DeviceChangeRequestRepository {

    private final Map<String, DeviceChangeRequest> requestsById = new ConcurrentHashMap<>();
    private final InMemoryDeviceArchiveRepository archiveRepository;

    public InMemoryDeviceChangeRequestRepository(InMemoryDeviceArchiveRepository archiveRepository) {
        this.archiveRepository = archiveRepository;
        requestsById.put(
                "DCR-LOCAL-0002",
                new DeviceChangeRequest(
                        "DCR-LOCAL-0002",
                        "device-local-0002",
                        "RDVP-DEVICE-0002",
                        "Conveyor Line B-02",
                        "usr-field-operator",
                        null,
                        DeviceChangeRequestStatus.PENDING_REVIEW,
                        "Site marker location requires archive correction.",
                        Map.of(
                                "location.address",
                                new DeviceChangeValue("Plant 2 Packaging Area", "Plant 2 Packaging Area Section A")),
                        OffsetDateTime.parse("2026-05-29T10:10:00Z"),
                        null,
                        null,
                        null,
                        null));
    }

    @Override
    public Optional<DeviceChangeRequest> findById(String id) {
        return Optional.ofNullable(requestsById.get(id));
    }

    @Override
    public DeviceChangeRequestPage list(DeviceChangeRequestQuery query) {
        var items = requestsById.values()
                .stream()
                .filter(item -> query.status() == null || item.status() == query.status())
                .filter(item -> query.deviceCode() == null || item.deviceCode().equals(query.deviceCode()))
                .filter(item -> query.applicantId() == null || item.applicantId().equals(query.applicantId()))
                .sorted(Comparator.comparing(DeviceChangeRequest::createdAt).reversed())
                .skip((long) (query.page() - 1) * query.pageSize())
                .limit(query.pageSize())
                .toList();
        long total = requestsById.values()
                .stream()
                .filter(item -> query.status() == null || item.status() == query.status())
                .filter(item -> query.deviceCode() == null || item.deviceCode().equals(query.deviceCode()))
                .filter(item -> query.applicantId() == null || item.applicantId().equals(query.applicantId()))
                .count();
        return new DeviceChangeRequestPage(items, total);
    }

    @Override
    public boolean hasPendingByDeviceId(String deviceId) {
        return requestsById.values()
                .stream()
                .anyMatch(item -> item.deviceId().equals(deviceId) && item.status() == DeviceChangeRequestStatus.PENDING_REVIEW);
    }

    @Override
    public Optional<OffsetDateTime> findActiveFreezeUntil(String deviceId, OffsetDateTime now) {
        Optional<OffsetDateTime> requestFreeze = requestsById.values()
                .stream()
                .filter(item -> item.deviceId().equals(deviceId))
                .map(DeviceChangeRequest::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now))
                .max(Comparator.naturalOrder());
        Optional<OffsetDateTime> archiveFreeze = archiveRepository.findById(deviceId)
                .map(DeviceArchive::changeState)
                .map(DeviceArchive.ChangeState::freezeUntil)
                .filter(freezeUntil -> freezeUntil != null && freezeUntil.isAfter(now));
        return requestFreeze.isPresent() ? requestFreeze : archiveFreeze;
    }

    @Override
    public void create(DeviceChangeRequestCreate request) {
        DeviceArchive device = archiveRepository.findById(request.deviceId()).orElseThrow();
        DeviceChangeRequest item = new DeviceChangeRequest(
                request.id(),
                request.deviceId(),
                device.deviceCode(),
                device.name(),
                request.applicantId(),
                null,
                DeviceChangeRequestStatus.PENDING_REVIEW,
                request.reason(),
                request.changes(),
                request.createdAt(),
                null,
                null,
                null,
                null);
        requestsById.put(request.id(), item);
        archiveRepository.markPending(request.deviceId(), request.id());
    }

    @Override
    public void applyApprovedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime freezeUntil,
            DeviceArchiveUpdate archiveUpdate) {
        DeviceChangeRequest request = requestsById.get(requestId);
        requestsById.put(requestId, new DeviceChangeRequest(
                request.id(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                DeviceChangeRequestStatus.APPROVED,
                request.reason(),
                request.changes(),
                request.createdAt(),
                reviewerId,
                reviewComment,
                reviewedAt,
                freezeUntil));
        archiveRepository.applyUpdate(archiveUpdate, freezeUntil);
    }

    @Override
    public void applyRejectedReview(
            String requestId,
            String reviewerId,
            String reviewComment,
            OffsetDateTime reviewedAt) {
        DeviceChangeRequest request = requestsById.get(requestId);
        requestsById.put(requestId, new DeviceChangeRequest(
                request.id(),
                request.deviceId(),
                request.deviceCode(),
                request.deviceName(),
                request.applicantId(),
                request.applicantName(),
                DeviceChangeRequestStatus.REJECTED,
                request.reason(),
                request.changes(),
                request.createdAt(),
                reviewerId,
                reviewComment,
                reviewedAt,
                null));
        archiveRepository.clearPending(request.deviceId());
    }
}
