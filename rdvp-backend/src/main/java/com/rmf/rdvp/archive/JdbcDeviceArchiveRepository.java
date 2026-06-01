package com.rmf.rdvp.archive;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcDeviceArchiveRepository implements DeviceArchiveRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcDeviceArchiveRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<DeviceArchive> findByCode(String deviceCode) {
        List<DeviceArchive> results = jdbcTemplate.query(
                """
                        SELECT
                            d.id,
                            d.device_code,
                            d.name,
                            d.model,
                            d.manufacturer,
                            d.status,
                            d.address,
                            d.longitude,
                            d.latitude,
                            d.last_verification_time,
                            pcr.id AS pending_request_id,
                            fcr.freeze_until
                        FROM devices d
                        LEFT JOIN device_change_requests pcr
                          ON pcr.device_id = d.id AND pcr.status = 'PENDING_REVIEW'
                        LEFT JOIN LATERAL (
                            SELECT freeze_until
                            FROM device_change_requests
                            WHERE device_id = d.id
                              AND freeze_until IS NOT NULL
                              AND freeze_until > now()
                            ORDER BY freeze_until DESC
                            LIMIT 1
                        ) fcr ON true
                        WHERE d.device_code = :deviceCode
                          AND d.deleted_at IS NULL
                        """,
                Map.of("deviceCode", deviceCode),
                this::mapDeviceArchive);
        return results.stream().findFirst();
    }

    @Override
    public Optional<DeviceArchive> findById(String id) {
        List<DeviceArchive> results = jdbcTemplate.query(
                """
                        SELECT
                            d.id,
                            d.device_code,
                            d.name,
                            d.model,
                            d.manufacturer,
                            d.status,
                            d.address,
                            d.longitude,
                            d.latitude,
                            d.last_verification_time,
                            pcr.id AS pending_request_id,
                            fcr.freeze_until
                        FROM devices d
                        LEFT JOIN device_change_requests pcr
                          ON pcr.device_id = d.id AND pcr.status = 'PENDING_REVIEW'
                        LEFT JOIN LATERAL (
                            SELECT freeze_until
                            FROM device_change_requests
                            WHERE device_id = d.id
                              AND freeze_until IS NOT NULL
                              AND freeze_until > now()
                            ORDER BY freeze_until DESC
                            LIMIT 1
                        ) fcr ON true
                        WHERE d.id = :id
                          AND d.deleted_at IS NULL
                        """,
                Map.of("id", id),
                this::mapDeviceArchive);
        return results.stream().findFirst();
    }

    private DeviceArchive mapDeviceArchive(ResultSet resultSet, int rowNumber) throws SQLException {
        String pendingRequestId = resultSet.getString("pending_request_id");
        OffsetDateTime freezeUntil = resultSet.getObject("freeze_until", OffsetDateTime.class);
        boolean locked = pendingRequestId != null || freezeUntil != null;
        return new DeviceArchive(
                resultSet.getString("id"),
                resultSet.getString("device_code"),
                resultSet.getString("name"),
                resultSet.getString("model"),
                resultSet.getString("manufacturer"),
                resultSet.getString("status"),
                resultSet.getString("address"),
                resultSet.getBigDecimal("longitude"),
                resultSet.getBigDecimal("latitude"),
                resultSet.getObject("last_verification_time", OffsetDateTime.class),
                new DeviceArchive.ChangeState(locked, pendingRequestId, freezeUntil));
    }
}
