package com.rmf.rdvp.archive;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryDeviceVerificationReportRepository implements DeviceVerificationReportRepository {

    private final Map<String, DeviceVerificationReport> reportsById = new ConcurrentHashMap<>();

    @Override
    public void create(DeviceVerificationReportCreate create) {
        reportsById.put(create.id(), new DeviceVerificationReport(
                create.id(),
                create.deviceId(),
                create.operatorId(),
                create.result(),
                create.description(),
                create.remark(),
                create.verifiedAt(),
                create.createdAt()));
    }

    @Override
    public Optional<DeviceVerificationReport> findById(String id) {
        return Optional.ofNullable(reportsById.get(id));
    }

    @Override
    public long countAll() {
        return reportsById.size();
    }
}
