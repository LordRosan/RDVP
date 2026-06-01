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
public class InMemoryDeviceArchiveRepository implements DeviceArchiveRepository {

    private final Map<String, DeviceArchive> devicesById = new ConcurrentHashMap<>();
    private final Set<String> deletedDeviceCodes = java.util.Collections.synchronizedSet(new HashSet<>());

    public InMemoryDeviceArchiveRepository() {
        OffsetDateTime frozenUntil = OffsetDateTime.now().plusHours(12);
        devicesById.put(
                "device-local-0001",
                new DeviceArchive(
                        "device-local-0001",
                        "RDVP-DEVICE-0001",
                        "Cooling Pump A-01",
                        "CP-1000",
                        "North Equipment",
                        "NORMAL",
                        "Plant 1 Power Area",
                        new BigDecimal("114.1694000"),
                        new BigDecimal("22.3193000"),
                        OffsetDateTime.parse("2026-05-28T09:30:00Z"),
                        new DeviceArchive.ChangeState(false, null, null)));
        devicesById.put(
                "device-local-0002",
                new DeviceArchive(
                        "device-local-0002",
                        "RDVP-DEVICE-0002",
                        "Conveyor Line B-02",
                        "CL-2200",
                        "South Automation",
                        "NORMAL",
                        "Plant 2 Packaging Area",
                        new BigDecimal("114.1721000"),
                        new BigDecimal("22.3188000"),
                        OffsetDateTime.parse("2026-05-27T15:20:00Z"),
                        new DeviceArchive.ChangeState(true, "DCR-LOCAL-0002", null)));
        devicesById.put(
                "device-local-0003",
                new DeviceArchive(
                        "device-local-0003",
                        "RDVP-DEVICE-0003",
                        "Energy Cabinet C-03",
                        "ES-500",
                        "East Energy",
                        "NORMAL",
                        "Plant 3 Energy Storage Area",
                        new BigDecimal("114.1662000"),
                        new BigDecimal("22.3210000"),
                        OffsetDateTime.parse("2026-05-26T11:10:00Z"),
                        new DeviceArchive.ChangeState(true, null, frozenUntil)));
    }

    @Override
    public Optional<DeviceArchive> findByCode(String deviceCode) {
        return devicesById.values()
                .stream()
                .filter(device -> device.deviceCode().equals(deviceCode))
                .findFirst();
    }

    @Override
    public Optional<DeviceArchive> findById(String id) {
        return Optional.ofNullable(devicesById.get(id));
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
    public void create(DeviceArchiveCreate create) {
        devicesById.put(create.id(), new DeviceArchive(
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
                new DeviceArchive.ChangeState(false, null, null)));
    }

    @Override
    public boolean softDelete(String id, String deletedBy, String deleteReason) {
        DeviceArchive removed = devicesById.remove(id);
        if (removed == null) {
            return false;
        }

        deletedDeviceCodes.add(removed.deviceCode());
        return true;
    }

    public void markPending(String deviceId, String requestId) {
        DeviceArchive device = devicesById.get(deviceId);
        if (device == null) {
            return;
        }

        devicesById.put(deviceId, copyWithChangeState(device, new DeviceArchive.ChangeState(true, requestId, null)));
    }

    public void applyUpdate(DeviceArchiveUpdate update, OffsetDateTime freezeUntil) {
        DeviceArchive device = devicesById.get(update.deviceId());
        if (device == null) {
            return;
        }

        devicesById.put(update.deviceId(), new DeviceArchive(
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
                new DeviceArchive.ChangeState(true, null, freezeUntil)));
    }

    public void clearPending(String deviceId) {
        DeviceArchive device = devicesById.get(deviceId);
        if (device == null) {
            return;
        }

        devicesById.put(deviceId, copyWithChangeState(device, new DeviceArchive.ChangeState(false, null, null)));
    }

    private DeviceArchive copyWithChangeState(DeviceArchive device, DeviceArchive.ChangeState changeState) {
        return new DeviceArchive(
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
                changeState);
    }
}
