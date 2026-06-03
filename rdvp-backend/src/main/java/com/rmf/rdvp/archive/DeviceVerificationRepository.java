package com.rmf.rdvp.archive;

import java.util.Optional;

public interface DeviceVerificationRepository {

    void create(DeviceVerificationRecordCreate create);

    Optional<DeviceVerificationRecord> findById(String id);
}
