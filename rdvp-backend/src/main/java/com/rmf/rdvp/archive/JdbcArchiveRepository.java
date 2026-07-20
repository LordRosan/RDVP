package com.rmf.rdvp.archive;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcArchiveRepository implements ArchiveRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcArchiveRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<Archive> findByCode(String deviceCode) {
        List<Archive> results = jdbcTemplate.query(
                """
                        SELECT
                            d.id,
                            d.device_code,
                            d.name,
                            d.device_type,
                            d.model,
                            d.manufacturer,
                            d.commissioned_at,
                            d.management_department,
                            d.status,
                            d.address,
                            d.longitude,
                            d.latitude,
                            d.last_verification_time,
                            pcr.id AS pending_request_id,
                            fcr.freeze_until
                        FROM archive_devices d
                        LEFT JOIN review_archive_requests pcr
                          ON pcr.device_id = d.id AND pcr.status = 'PENDING_REVIEW'
                        LEFT JOIN LATERAL (
                            SELECT freeze_until
                            FROM review_archive_requests
                            WHERE (device_id = d.id OR target_device_code = d.device_code)
                              AND freeze_until IS NOT NULL
                              AND freeze_until > now()
                            ORDER BY freeze_until DESC
                            LIMIT 1
                        ) fcr ON true
                        WHERE d.device_code = :deviceCode
                          AND d.deleted_at IS NULL
                        """,
                Map.of("deviceCode", deviceCode),
                this::mapArchive);
        return results.stream().findFirst();
    }

    @Override
    public Optional<Archive> findById(String id) {
        List<Archive> results = jdbcTemplate.query(
                """
                        SELECT
                            d.id,
                            d.device_code,
                            d.name,
                            d.device_type,
                            d.model,
                            d.manufacturer,
                            d.commissioned_at,
                            d.management_department,
                            d.status,
                            d.address,
                            d.longitude,
                            d.latitude,
                            d.last_verification_time,
                            pcr.id AS pending_request_id,
                            fcr.freeze_until
                        FROM archive_devices d
                        LEFT JOIN review_archive_requests pcr
                          ON pcr.device_id = d.id AND pcr.status = 'PENDING_REVIEW'
                        LEFT JOIN LATERAL (
                            SELECT freeze_until
                            FROM review_archive_requests
                            WHERE (device_id = d.id OR target_device_code = d.device_code)
                              AND freeze_until IS NOT NULL
                              AND freeze_until > now()
                            ORDER BY freeze_until DESC
                            LIMIT 1
                        ) fcr ON true
                        WHERE d.id = :id
                          AND d.deleted_at IS NULL
                        """,
                Map.of("id", id),
                this::mapArchive);
        return results.stream().findFirst();
    }

    @Override
    public long countActiveDevices() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM archive_devices
                        WHERE deleted_at IS NULL
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    @Override
    public boolean existsByCode(String deviceCode) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM archive_devices
                        WHERE device_code = :deviceCode
                          AND deleted_at IS NULL
                        """,
                Map.of("deviceCode", deviceCode),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public void create(ArchiveCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO archive_devices (
                            id,
                            device_code,
                            name,
                            device_type,
                            model,
                            manufacturer,
                            commissioned_at,
                            management_department,
                            status,
                            address,
                            longitude,
                            latitude,
                            created_at,
                            created_by,
                            updated_at,
                            updated_by
                        ) VALUES (
                            :id,
                            :deviceCode,
                            :name,
                            :deviceType,
                            :model,
                            :manufacturer,
                            :commissionedAt,
                            :managementDepartment,
                            :status,
                            :address,
                            :longitude,
                            :latitude,
                            :createdAt,
                            :createdBy,
                            :createdAt,
                            :createdBy
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("deviceCode", create.deviceCode())
                        .addValue("name", create.name())
                        .addValue("deviceType", create.deviceType())
                        .addValue("model", create.model())
                        .addValue("manufacturer", create.manufacturer())
                        .addValue("commissionedAt", create.commissionedAt())
                        .addValue("managementDepartment", create.managementDepartment())
                        .addValue("status", create.status())
                        .addValue("address", create.address())
                        .addValue("longitude", create.longitude())
                        .addValue("latitude", create.latitude())
                        .addValue("createdAt", create.createdAt())
                        .addValue("createdBy", create.createdBy()));
    }

    @Override
    public void updateStatus(String id, String status, String updatedBy) {
        jdbcTemplate.update(
                """
                        UPDATE archive_devices
                        SET status = :status,
                            updated_at = now(),
                            updated_by = :updatedBy
                        WHERE id = :id
                          AND deleted_at IS NULL
                        """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("status", status)
                        .addValue("updatedBy", updatedBy));
    }

    @Override
    public void updateLastVerificationTime(String id, OffsetDateTime verifiedAt, String updatedBy) {
        jdbcTemplate.update(
                """
                        UPDATE archive_devices
                        SET last_verification_time = :verifiedAt,
                            updated_at = now(),
                            updated_by = :updatedBy
                        WHERE id = :id
                          AND deleted_at IS NULL
                        """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("verifiedAt", verifiedAt)
                        .addValue("updatedBy", updatedBy));
    }

    @Override
    public boolean softDelete(String id, String deletedBy, String deleteReason) {
        int updated = jdbcTemplate.update(
                """
                        UPDATE archive_devices
                        SET deleted_at = now(),
                            deleted_reason = NULLIF(:deleteReason, ''),
                            updated_at = now(),
                            updated_by = :deletedBy
                        WHERE id = :id
                          AND deleted_at IS NULL
                        """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("deletedBy", deletedBy)
                        .addValue("deleteReason", deleteReason));
        return updated > 0;
    }

    private Archive mapArchive(ResultSet resultSet, int rowNumber) throws SQLException {
        String pendingRequestId = resultSet.getString("pending_request_id");
        OffsetDateTime freezeUntil = resultSet.getObject("freeze_until", OffsetDateTime.class);
        boolean locked = pendingRequestId != null || freezeUntil != null;
        return new Archive(
                resultSet.getString("id"),
                resultSet.getString("device_code"),
                resultSet.getString("name"),
                resultSet.getString("device_type"),
                resultSet.getString("model"),
                resultSet.getString("manufacturer"),
                resultSet.getObject("commissioned_at", LocalDate.class),
                resultSet.getString("management_department"),
                resultSet.getString("status"),
                resultSet.getString("address"),
                resultSet.getBigDecimal("longitude"),
                resultSet.getBigDecimal("latitude"),
                resultSet.getObject("last_verification_time", OffsetDateTime.class),
                new Archive.ArchiveRequestState(locked, pendingRequestId, freezeUntil));
    }
}
