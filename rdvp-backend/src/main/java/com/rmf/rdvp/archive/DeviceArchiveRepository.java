package com.rmf.rdvp.archive;

import java.util.Optional;

public interface DeviceArchiveRepository {

    Optional<DeviceArchive> findByCode(String deviceCode);

    Optional<DeviceArchive> findById(String id);

    boolean existsByCode(String deviceCode);

    void create(DeviceArchiveCreate create);

    boolean softDelete(String id, String deletedBy, String deleteReason);
}
