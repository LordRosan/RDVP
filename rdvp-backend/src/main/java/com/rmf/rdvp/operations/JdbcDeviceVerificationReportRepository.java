package com.rmf.rdvp.operations;

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
public class JdbcDeviceVerificationReportRepository implements DeviceVerificationReportRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcDeviceVerificationReportRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void create(DeviceVerificationReportCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO operations_device_verification_reports (
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
    public Optional<DeviceVerificationReport> findById(String id) {
        List<DeviceVerificationReport> results = jdbcTemplate.query(
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
                        FROM operations_device_verification_reports
                        WHERE id = :id
                        """,
                Map.of("id", id),
                this::mapReport);
        return results.stream().findFirst();
    }

    @Override
    public long countAll() {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM operations_device_verification_reports
                        """,
                Map.of(),
                Long.class);
        return count == null ? 0 : count;
    }

    private DeviceVerificationReport mapReport(ResultSet resultSet, int rowNumber) throws SQLException {
        return new DeviceVerificationReport(
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
