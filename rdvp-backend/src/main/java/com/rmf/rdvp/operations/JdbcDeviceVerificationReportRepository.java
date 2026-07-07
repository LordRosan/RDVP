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
                            verification_type,
                            device_status,
                            verification_method,
                            result,
                            description,
                            remark,
                            verified_at,
                            created_at
                        ) VALUES (
                            :id,
                            :deviceId,
                            :operatorId,
                            :verificationType,
                            :deviceStatus,
                            :verificationMethod,
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
                        .addValue("verificationType", create.verificationType().name())
                        .addValue("deviceStatus", create.deviceStatus().name())
                        .addValue("verificationMethod", create.verificationMethod().name())
                        .addValue("result", create.result().name())
                        .addValue("description", create.description())
                        .addValue("remark", create.remark())
                        .addValue("verifiedAt", create.verifiedAt())
                        .addValue("createdAt", create.createdAt()));
        if (!create.items().isEmpty()) {
            jdbcTemplate.batchUpdate(
                    """
                            INSERT INTO operations_device_verification_report_items (
                                verification_report_id,
                                item_code,
                                item_name,
                                result,
                                display_order
                            ) VALUES (
                                :verificationReportId,
                                :itemCode,
                                :itemName,
                                :result,
                                :displayOrder
                            )
                            """,
                    create.items()
                            .stream()
                            .map(item -> new MapSqlParameterSource()
                                    .addValue("verificationReportId", create.id())
                                    .addValue("itemCode", item.itemCode())
                                    .addValue("itemName", item.itemName())
                                    .addValue("result", item.result().name())
                                    .addValue("displayOrder", item.displayOrder()))
                            .toArray(MapSqlParameterSource[]::new));
        }
    }

    @Override
    public Optional<DeviceVerificationReport> findById(String id) {
        List<DeviceVerificationReport> results = jdbcTemplate.query(
                """
                        SELECT
                            id,
                            device_id,
                            operator_id,
                            verification_type,
                            device_status,
                            verification_method,
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
        return results.stream()
                .findFirst()
                .map(report -> new DeviceVerificationReport(
                        report.id(),
                        report.deviceId(),
                        report.operatorId(),
                        report.verificationType(),
                        report.deviceStatus(),
                        report.verificationMethod(),
                        report.result(),
                        findItemsByReportId(report.id()),
                        report.description(),
                        report.remark(),
                        report.verifiedAt(),
                        report.createdAt()));
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
                VerificationType.valueOf(resultSet.getString("verification_type")),
                VerificationDeviceStatus.valueOf(resultSet.getString("device_status")),
                VerificationMethod.valueOf(resultSet.getString("verification_method")),
                DeviceVerificationResult.valueOf(resultSet.getString("result")),
                List.of(),
                resultSet.getString("description"),
                resultSet.getString("remark"),
                resultSet.getObject("verified_at", OffsetDateTime.class),
                resultSet.getObject("created_at", OffsetDateTime.class));
    }

    private List<DeviceVerificationReportItem> findItemsByReportId(String reportId) {
        return jdbcTemplate.query(
                """
                        SELECT
                            item_code,
                            item_name,
                            result,
                            display_order
                        FROM operations_device_verification_report_items
                        WHERE verification_report_id = :reportId
                        ORDER BY display_order ASC
                        """,
                Map.of("reportId", reportId),
                (resultSet, rowNumber) -> new DeviceVerificationReportItem(
                        resultSet.getString("item_code"),
                        resultSet.getString("item_name"),
                        VerificationItemResult.valueOf(resultSet.getString("result")),
                        resultSet.getInt("display_order")));
    }
}
