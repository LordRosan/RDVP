package com.rmf.rdvp.archive;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryDeviceVerificationRepository implements DeviceVerificationRepository {

    private final Map<String, DeviceVerificationRecord> recordsById = new ConcurrentHashMap<>();

    @Override
    public void create(DeviceVerificationRecordCreate create) {
        recordsById.put(create.id(), new DeviceVerificationRecord(
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
    public Optional<DeviceVerificationRecord> findById(String id) {
        return Optional.ofNullable(recordsById.get(id));
    }

    @Override
    public long countAll() {
        return recordsById.size();
    }
}
