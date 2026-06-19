package com.rmf.rdvp.archive;

import java.util.Optional;

public interface DeviceArchiveRepository {

    Optional<DeviceArchive> findByCode(String deviceCode);

    Optional<DeviceArchive> findById(String id);

    long countActiveDevices();

    boolean existsByCode(String deviceCode);

    void create(DeviceArchiveCreate create);

    void updateStatus(String id, String status, String updatedBy);

    void updateLastVerificationTime(String id, java.time.OffsetDateTime verifiedAt, String updatedBy);

    boolean softDelete(String id, String deletedBy, String deleteReason);
}
