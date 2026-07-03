package com.rmf.rdvp.archive;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryArchiveRepository implements ArchiveRepository {

    private final Map<String, Archive> devicesById = new ConcurrentHashMap<>();
    private final Set<String> deletedDeviceCodes = java.util.Collections.synchronizedSet(new HashSet<>());

    public InMemoryArchiveRepository() {
        OffsetDateTime frozenUntil = OffsetDateTime.now().plusHours(12);
        devicesById.put(
                "device-local-0001",
                new Archive(
                        "device-local-0001",
                        "RDVP-DEVICE-0001",
                        "冷却泵A-01",
                        "CP-1000",
                        "北方设备",
                        "NORMAL",
                        "一号厂房动力区",
                        new BigDecimal("114.1694000"),
                        new BigDecimal("22.3193000"),
                        OffsetDateTime.parse("2026-05-28T09:30:00Z"),
                        new Archive.ArchiveRequestState(false, null, null)));
        devicesById.put(
                "device-local-0002",
                new Archive(
                        "device-local-0002",
                        "RDVP-DEVICE-0002",
                        "输送线B-02",
                        "CL-2200",
                        "南部自动化",
                        "NORMAL",
                        "二号厂房包装区",
                        new BigDecimal("114.1721000"),
                        new BigDecimal("22.3188000"),
                        OffsetDateTime.parse("2026-05-27T15:20:00Z"),
                        new Archive.ArchiveRequestState(true, "DCR-LOCAL-0002", null)));
        devicesById.put(
                "device-local-0003",
                new Archive(
                        "device-local-0003",
                        "RDVP-DEVICE-0003",
                        "储能柜C-03",
                        "ES-500",
                        "东部能源",
                        "NORMAL",
                        "三号厂房储能区",
                        new BigDecimal("114.1662000"),
                        new BigDecimal("22.3210000"),
                        OffsetDateTime.parse("2026-05-26T11:10:00Z"),
                        new Archive.ArchiveRequestState(true, null, frozenUntil)));
    }

    @Override
    public Optional<Archive> findByCode(String deviceCode) {
        return devicesById.values()
                .stream()
                .filter(device -> device.deviceCode().equals(deviceCode))
                .findFirst();
    }

    @Override
    public Optional<Archive> findById(String id) {
        return Optional.ofNullable(devicesById.get(id));
    }

    @Override
    public long countActiveDevices() {
        return devicesById.size();
    }

    @Override
    public boolean existsByCode(String deviceCode) {
        if (deletedDeviceCodes.contains(deviceCode)) {
            return true;
        }

        return devicesById.values()
                .stream()
                .anyMatch(device -> device.deviceCode().equals(deviceCode));
    }

    @Override
    public void create(ArchiveCreate create) {
        devicesById.put(create.id(), new Archive(
                create.id(),
                create.deviceCode(),
                create.name(),
                create.model(),
                create.manufacturer(),
                create.status(),
                create.address(),
                create.longitude(),
                create.latitude(),
                null,
                new Archive.ArchiveRequestState(false, null, null)));
    }

    @Override
    public void updateStatus(String id, String status, String updatedBy) {
        Archive device = devicesById.get(id);
        if (device == null) {
            return;
        }

        devicesById.put(id, new Archive(
                device.id(),
                device.deviceCode(),
                device.name(),
                device.model(),
                device.manufacturer(),
                status,
                device.address(),
                device.longitude(),
                device.latitude(),
                device.lastVerificationTime(),
                device.archiveRequestState()));
    }

    @Override
    public void updateLastVerificationTime(String id, OffsetDateTime verifiedAt, String updatedBy) {
        Archive device = devicesById.get(id);
        if (device == null) {
            return;
        }

        devicesById.put(id, new Archive(
                device.id(),
                device.deviceCode(),
                device.name(),
                device.model(),
                device.manufacturer(),
                device.status(),
                device.address(),
                device.longitude(),
                device.latitude(),
                verifiedAt,
                device.archiveRequestState()));
    }

    @Override
    public boolean softDelete(String id, String deletedBy, String deleteReason) {
        Archive removed = devicesById.remove(id);
        if (removed == null) {
            return false;
        }

        deletedDeviceCodes.add(removed.deviceCode());
        return true;
    }

    public void markPending(String deviceId, String requestId) {
        Archive device = devicesById.get(deviceId);
        if (device == null) {
            return;
        }

        devicesById.put(deviceId, copyWithArchiveRequestState(device, new Archive.ArchiveRequestState(true, requestId, null)));
    }

    public void applyUpdate(ArchiveUpdate update, OffsetDateTime freezeUntil) {
        Archive device = devicesById.get(update.deviceId());
        if (device == null) {
            return;
        }

        devicesById.put(update.deviceId(), new Archive(
                device.id(),
                device.deviceCode(),
                update.name(),
                update.model(),
                update.manufacturer(),
                device.status(),
                update.address(),
                device.longitude(),
                device.latitude(),
                device.lastVerificationTime(),
                new Archive.ArchiveRequestState(true, null, freezeUntil)));
    }

    public void clearPending(String deviceId) {
        Archive device = devicesById.get(deviceId);
        if (device == null) {
            return;
        }

        devicesById.put(deviceId, copyWithArchiveRequestState(device, new Archive.ArchiveRequestState(false, null, null)));
    }

    public void freeze(String deviceId, OffsetDateTime freezeUntil) {
        Archive device = devicesById.get(deviceId);
        if (device == null) {
            return;
        }

        devicesById.put(deviceId, copyWithArchiveRequestState(device, new Archive.ArchiveRequestState(true, null, freezeUntil)));
    }

    public void freezeByCode(String deviceCode, OffsetDateTime freezeUntil) {
        findByCode(deviceCode).ifPresent(device ->
                devicesById.put(device.id(),
                        copyWithArchiveRequestState(device, new Archive.ArchiveRequestState(true, null, freezeUntil))));
    }

    private Archive copyWithArchiveRequestState(
            Archive device,
            Archive.ArchiveRequestState archiveRequestState) {
        return new Archive(
                device.id(),
                device.deviceCode(),
                device.name(),
                device.model(),
                device.manufacturer(),
                device.status(),
                device.address(),
                device.longitude(),
                device.latitude(),
                device.lastVerificationTime(),
                archiveRequestState);
    }
}
