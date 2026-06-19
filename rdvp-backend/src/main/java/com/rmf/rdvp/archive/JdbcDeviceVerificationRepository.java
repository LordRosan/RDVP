package com.rmf.rdvp.archive;

import java.sql.ResultSet;
import java.sql.SQLException;
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
public class JdbcDeviceVerificationRepository implements DeviceVerificationRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcDeviceVerificationRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void create(DeviceVerificationRecordCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO device_verification_records (
                            id,
                            device_id,
                            operator_id,
                            result,
                            description,
                            remark,
                            verified_at,
                            created_at
                        ) VALUES (
                            :id,
                            :deviceId,
                            :operatorId,
                            :result,
                            :description,
                            :remark,
                            :verifiedAt,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("deviceId", create.deviceId())
                        .addValue("operatorId", create.operatorId())
                        .addValue("result", create.result().name())
                        .addValue("description", create.description())
                        .addValue("remark", create.remark())
                        .addValue("verifiedAt", create.verifiedAt())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public Optional<DeviceVerificationRecord> findById(String id) {
        List<DeviceVerificationRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            id,
                            device_id,
                            operator_id,
                            result,
                            description,
                            remark,
                            verified_at,
                            created_at
                        FROM device_verification_records
                        WHERE id = :id
                        """,
                Map.of("id", id),
                this::mapRecord);
        return results.stream().findFirst();
    }

    @Override
    public long countAll() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM device_verification_records
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    private DeviceVerificationRecord mapRecord(ResultSet resultSet, int rowNumber) throws SQLException {
        return new DeviceVerificationRecord(
                resultSet.getString("id"),
                resultSet.getString("device_id"),
                resultSet.getString("operator_id"),
                DeviceVerificationResult.valueOf(resultSet.getString("result")),
                resultSet.getString("description"),
                resultSet.getString("remark"),
                resultSet.getObject("verified_at", OffsetDateTime.class),
                resultSet.getObject("created_at", OffsetDateTime.class));
    }
}
