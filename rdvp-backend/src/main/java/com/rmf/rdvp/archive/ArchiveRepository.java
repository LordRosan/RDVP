package com.rmf.rdvp.archive;

import java.util.Optional;

public interface ArchiveRepository {

    Optional<Archive> findByCode(String deviceCode);

    Optional<Archive> findById(String id);

    long countActiveDevices();

    boolean existsByCode(String deviceCode);

    void create(ArchiveCreate create);

    void updateStatus(String id, String status, String updatedBy);

    void updateLastVerificationTime(String id, java.time.OffsetDateTime verifiedAt, String updatedBy);

    boolean softDelete(String id, String deletedBy, String deleteReason);
}
