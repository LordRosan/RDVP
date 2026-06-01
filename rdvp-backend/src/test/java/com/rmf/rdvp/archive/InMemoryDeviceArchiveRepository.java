package com.rmf.rdvp.archive;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryDeviceArchiveRepository implements DeviceArchiveRepository {

    private final Map<String, DeviceArchive> devicesById;
    private final Map<String, DeviceArchive> devicesByCode;

    public InMemoryDeviceArchiveRepository() {
        OffsetDateTime frozenUntil = OffsetDateTime.now().plusHours(12);
        this.devicesById = Map.of(
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
                        new DeviceArchive.ChangeState(false, null, null)),
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
                        new DeviceArchive.ChangeState(true, "DCR-LOCAL-0002", null)),
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
        this.devicesByCode = devicesById.values()
                .stream()
                .collect(Collectors.toUnmodifiableMap(DeviceArchive::deviceCode, Function.identity()));
    }

    @Override
    public Optional<DeviceArchive> findByCode(String deviceCode) {
        return Optional.ofNullable(devicesByCode.get(deviceCode));
    }

    @Override
    public Optional<DeviceArchive> findById(String id) {
        return Optional.ofNullable(devicesById.get(id));
    }
}
