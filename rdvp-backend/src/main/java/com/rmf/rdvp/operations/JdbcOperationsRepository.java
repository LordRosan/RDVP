package com.rmf.rdvp.operations;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcOperationsRepository implements OperationsRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcOperationsRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void createFaultReport(FaultReportCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO fault_reports (
                            id,
                            fault_report_no,
                            device_id,
                            reporter_id,
                            fault_type,
                            severity,
                            status,
                            occurred_at,
                            description,
                            scene_condition,
                            longitude,
                            latitude,
                            created_at,
                            updated_at
                        ) VALUES (
                            :id,
                            :faultReportNo,
                            :deviceId,
                            :reporterId,
                            :faultType,
                            :severity,
                            'PENDING_ACCEPTANCE',
                            :occurredAt,
                            :description,
                            :sceneCondition,
                            :longitude,
                            :latitude,
                            :createdAt,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("faultReportNo", create.faultReportNo())
                        .addValue("deviceId", create.deviceId())
                        .addValue("reporterId", create.reporterId())
                        .addValue("faultType", create.faultType().name())
                        .addValue("severity", create.severity().name())
                        .addValue("occurredAt", create.occurredAt())
                        .addValue("description", create.description())
                        .addValue("sceneCondition", create.sceneCondition())
                        .addValue("longitude", create.longitude())
                        .addValue("latitude", create.latitude())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public Optional<FaultReportRecord> findFaultReportByIdOrNo(String idOrNo) {
        List<FaultReportRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            id,
                            fault_report_no,
                            device_id,
                            reporter_id,
                            fault_type,
                            severity,
                            status,
                            description,
                            scene_condition,
                            occurred_at,
                            longitude,
                            latitude,
                            accepted_task_id,
                            created_at,
                            updated_at
                        FROM fault_reports
                        WHERE id = :idOrNo
                           OR fault_report_no = :idOrNo
                        """,
                Map.of("idOrNo", idOrNo),
                this::mapFaultReport);
        return results.stream().findFirst();
    }

    @Override
    public List<AvailableRepairTaskSummary> listAvailableRepairTasks(FaultSeverity severity) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource parameters = new MapSqlParameterSource();
        conditions.add("f.status = 'PENDING_ACCEPTANCE'");
        conditions.add("d.deleted_at IS NULL");
        if (severity != null) {
            conditions.add("f.severity = :severity");
            parameters.addValue("severity", severity.name());
        }

        return jdbcTemplate.query(
                """
                        SELECT
                            f.id,
                            f.fault_report_no,
                            d.device_code,
                            d.name AS device_name,
                            f.fault_type,
                            f.severity,
                            d.address,
                            d.longitude,
                            d.latitude,
                            f.created_at
                        FROM fault_reports f
                        JOIN devices d ON d.id = f.device_id
                        WHERE %s
                        ORDER BY f.created_at DESC
                        """.formatted(String.join(" AND ", conditions)),
                parameters,
                this::mapAvailableRepairTask);
    }

    @Override
    public boolean hasActiveRepairTaskForFault(String faultReportId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM repair_tasks
                        WHERE fault_report_id = :faultReportId
                          AND status <> 'REPORT_SUBMITTED'
                        """,
                Map.of("faultReportId", faultReportId),
                Integer.class);
        return count != null && count > 0;
    }

    @Override
    public int countActiveRepairTasksByMaintainer(String maintainerId) {
        Integer count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM repair_tasks
                        WHERE maintainer_id = :maintainerId
                          AND status IN ('ACCEPTED', 'PROCESSING')
                        """,
                Map.of("maintainerId", maintainerId),
                Integer.class);
        return count == null ? 0 : count;
    }

    @Override
    public void createRepairTask(RepairTaskCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO repair_tasks (
                            id,
                            repair_task_no,
                            fault_report_id,
                            maintainer_id,
                            status,
                            accepted_longitude,
                            accepted_latitude,
                            accepted_at,
                            created_at,
                            updated_at
                        ) VALUES (
                            :id,
                            :repairTaskNo,
                            :faultReportId,
                            :maintainerId,
                            'ACCEPTED',
                            :acceptedLongitude,
                            :acceptedLatitude,
                            :acceptedAt,
                            :acceptedAt,
                            :acceptedAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("repairTaskNo", create.repairTaskNo())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("maintainerId", create.maintainerId())
                        .addValue("acceptedLongitude", create.acceptedLongitude())
                        .addValue("acceptedLatitude", create.acceptedLatitude())
                        .addValue("acceptedAt", create.acceptedAt()));
    }

    @Override
    public void markFaultAccepted(String faultReportId, String repairTaskId, OffsetDateTime updatedAt) {
        jdbcTemplate.update(
                """
                        UPDATE fault_reports
                        SET status = 'ACCEPTED',
                            accepted_task_id = :repairTaskId,
                            updated_at = :updatedAt
                        WHERE id = :faultReportId
                        """,
                new MapSqlParameterSource()
                        .addValue("faultReportId", faultReportId)
                        .addValue("repairTaskId", repairTaskId)
                        .addValue("updatedAt", updatedAt));
    }

    @Override
    public List<MyRepairTaskSummary> listMyRepairTasks(String maintainerId) {
        return jdbcTemplate.query(
                """
                        SELECT
                            rt.id,
                            rt.repair_task_no,
                            f.fault_report_no,
                            d.device_code,
                            d.name AS device_name,
                            f.fault_type,
                            f.severity,
                            rt.accepted_at,
                            rt.status
                        FROM repair_tasks rt
                        JOIN fault_reports f ON f.id = rt.fault_report_id
                        JOIN devices d ON d.id = f.device_id
                        WHERE rt.maintainer_id = :maintainerId
                          AND rt.status <> 'REPORT_SUBMITTED'
                          AND d.deleted_at IS NULL
                        ORDER BY rt.accepted_at DESC
                        """,
                Map.of("maintainerId", maintainerId),
                this::mapMyRepairTask);
    }

    @Override
    public Optional<RepairTaskRecord> findRepairTaskByIdOrNo(String idOrNo) {
        List<RepairTaskRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            rt.id,
                            rt.repair_task_no,
                            rt.fault_report_id,
                            f.device_id,
                            rt.maintainer_id,
                            f.severity,
                            rt.status,
                            rt.accepted_longitude,
                            rt.accepted_latitude,
                            rt.accepted_at,
                            rt.completed_at
                        FROM repair_tasks rt
                        JOIN fault_reports f ON f.id = rt.fault_report_id
                        WHERE rt.id = :idOrNo
                           OR rt.repair_task_no = :idOrNo
                        """,
                Map.of("idOrNo", idOrNo),
                this::mapRepairTask);
        return results.stream().findFirst();
    }

    @Override
    public List<ReinspectionTaskSummary> listPendingReinspections() {
        return jdbcTemplate.query(
                """
                        SELECT
                            f.id,
                            f.fault_report_no,
                            d.device_code,
                            d.name AS device_name,
                            f.severity,
                            d.address,
                            d.longitude,
                            d.latitude,
                            latest_report.repaired_at,
                            f.status
                        FROM fault_reports f
                        JOIN devices d ON d.id = f.device_id
                        LEFT JOIN LATERAL (
                            SELECT rr.repaired_at
                            FROM repair_reports rr
                            WHERE rr.fault_report_id = f.id
                            ORDER BY rr.created_at DESC
                            LIMIT 1
                        ) latest_report ON TRUE
                        WHERE f.status = 'PENDING_REINSPECTION'
                          AND d.deleted_at IS NULL
                        ORDER BY f.updated_at DESC
                        """,
                Map.of(),
                this::mapReinspectionTask);
    }

    @Override
    public void createRepairReport(RepairReportCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO repair_reports (
                            id,
                            repair_report_no,
                            repair_task_id,
                            fault_report_id,
                            maintainer_id,
                            result,
                            repaired_at,
                            process_description,
                            parts_used,
                            requires_reinspection,
                            created_at
                        ) VALUES (
                            :id,
                            :repairReportNo,
                            :repairTaskId,
                            :faultReportId,
                            :maintainerId,
                            :result,
                            :repairedAt,
                            :processDescription,
                            :partsUsed,
                            :requiresReinspection,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("repairReportNo", create.repairReportNo())
                        .addValue("repairTaskId", create.repairTaskId())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("maintainerId", create.maintainerId())
                        .addValue("result", create.result().name())
                        .addValue("repairedAt", create.repairedAt())
                        .addValue("processDescription", create.processDescription())
                        .addValue("partsUsed", create.partsUsed())
                        .addValue("requiresReinspection", create.requiresReinspection())
                        .addValue("createdAt", create.createdAt()));
    }

    @Override
    public Optional<RepairReportRecord> findLatestRepairReportByFaultReportId(String faultReportId) {
        List<RepairReportRecord> results = jdbcTemplate.query(
                """
                        SELECT
                            id,
                            repair_report_no,
                            repair_task_id,
                            fault_report_id,
                            maintainer_id,
                            result,
                            repaired_at,
                            process_description,
                            parts_used,
                            requires_reinspection,
                            created_at
                        FROM repair_reports
                        WHERE fault_report_id = :faultReportId
                        ORDER BY created_at DESC
                        LIMIT 1
                        """,
                Map.of("faultReportId", faultReportId),
                this::mapRepairReport);
        return results.stream().findFirst();
    }

    @Override
    public void markRepairTaskReported(String repairTaskId, OffsetDateTime completedAt) {
        jdbcTemplate.update(
                """
                        UPDATE repair_tasks
                        SET status = 'REPORT_SUBMITTED',
                            completed_at = :completedAt,
                            updated_at = :completedAt
                        WHERE id = :repairTaskId
                        """,
                new MapSqlParameterSource()
                        .addValue("repairTaskId", repairTaskId)
                        .addValue("completedAt", completedAt));
    }

    @Override
    public void updateFaultStatus(String faultReportId, FaultStatus status, OffsetDateTime updatedAt) {
        jdbcTemplate.update(
                """
                        UPDATE fault_reports
                        SET status = :status,
                            closed_at = CASE WHEN :status = 'CLOSED' THEN :updatedAt ELSE closed_at END,
                            accepted_task_id = CASE WHEN :status = 'PENDING_ACCEPTANCE' THEN NULL ELSE accepted_task_id END,
                            updated_at = :updatedAt
                        WHERE id = :faultReportId
                        """,
                new MapSqlParameterSource()
                        .addValue("faultReportId", faultReportId)
                        .addValue("status", status.name())
                        .addValue("updatedAt", updatedAt));
    }

    @Override
    public void createReinspectionRecord(ReinspectionRecordCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO reinspection_records (
                            id,
                            reinspection_record_no,
                            fault_report_id,
                            repair_report_id,
                            reinspector_id,
                            result,
                            reinspected_at,
                            description,
                            created_at
                        ) VALUES (
                            :id,
                            :reinspectionRecordNo,
                            :faultReportId,
                            :repairReportId,
                            :reinspectorId,
                            :result,
                            :reinspectedAt,
                            :description,
                            :createdAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("reinspectionRecordNo", create.reinspectionRecordNo())
                        .addValue("faultReportId", create.faultReportId())
                        .addValue("repairReportId", create.repairReportId())
                        .addValue("reinspectorId", create.reinspectorId())
                        .addValue("result", create.result().name())
                        .addValue("reinspectedAt", create.reinspectedAt())
                        .addValue("description", create.description())
                        .addValue("createdAt", create.createdAt()));
    }

    private FaultReportRecord mapFaultReport(ResultSet resultSet, int rowNumber) throws SQLException {
        return new FaultReportRecord(
                resultSet.getString("id"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_id"),
                resultSet.getString("reporter_id"),
                FaultType.valueOf(resultSet.getString("fault_type")),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                FaultStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("description"),
                resultSet.getString("scene_condition"),
                resultSet.getObject("occurred_at", OffsetDateTime.class),
                resultSet.getBigDecimal("longitude"),
                resultSet.getBigDecimal("latitude"),
                resultSet.getString("accepted_task_id"),
                resultSet.getObject("created_at", OffsetDateTime.class),
                resultSet.getObject("updated_at", OffsetDateTime.class));
    }

    private AvailableRepairTaskSummary mapAvailableRepairTask(ResultSet resultSet, int rowNumber) throws SQLException {
        return new AvailableRepairTaskSummary(
                resultSet.getString("id"),
                resultSet.getString("id"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                FaultType.valueOf(resultSet.getString("fault_type")),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                BigDecimal.ZERO,
                new AvailableRepairTaskSummary.DeviceLocation(
                        resultSet.getString("address"),
                        resultSet.getBigDecimal("longitude"),
                        resultSet.getBigDecimal("latitude")),
                resultSet.getObject("created_at", OffsetDateTime.class),
                RepairTaskStatus.AVAILABLE);
    }

    private MyRepairTaskSummary mapMyRepairTask(ResultSet resultSet, int rowNumber) throws SQLException {
        return new MyRepairTaskSummary(
                resultSet.getString("id"),
                resultSet.getString("repair_task_no"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                FaultType.valueOf(resultSet.getString("fault_type")),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                resultSet.getObject("accepted_at", OffsetDateTime.class),
                RepairTaskStatus.valueOf(resultSet.getString("status")));
    }

    private RepairTaskRecord mapRepairTask(ResultSet resultSet, int rowNumber) throws SQLException {
        return new RepairTaskRecord(
                resultSet.getString("id"),
                resultSet.getString("repair_task_no"),
                resultSet.getString("fault_report_id"),
                resultSet.getString("device_id"),
                resultSet.getString("maintainer_id"),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                RepairTaskStatus.valueOf(resultSet.getString("status")),
                resultSet.getBigDecimal("accepted_longitude"),
                resultSet.getBigDecimal("accepted_latitude"),
                resultSet.getObject("accepted_at", OffsetDateTime.class),
                resultSet.getObject("completed_at", OffsetDateTime.class));
    }

    private ReinspectionTaskSummary mapReinspectionTask(ResultSet resultSet, int rowNumber) throws SQLException {
        return new ReinspectionTaskSummary(
                resultSet.getString("id"),
                resultSet.getString("id"),
                resultSet.getString("fault_report_no"),
                resultSet.getString("device_code"),
                resultSet.getString("device_name"),
                FaultSeverity.valueOf(resultSet.getString("severity")),
                new AvailableRepairTaskSummary.DeviceLocation(
                        resultSet.getString("address"),
                        resultSet.getBigDecimal("longitude"),
                        resultSet.getBigDecimal("latitude")),
                resultSet.getObject("repaired_at", OffsetDateTime.class),
                FaultStatus.valueOf(resultSet.getString("status")));
    }

    private RepairReportRecord mapRepairReport(ResultSet resultSet, int rowNumber) throws SQLException {
        return new RepairReportRecord(
                resultSet.getString("id"),
                resultSet.getString("repair_report_no"),
                resultSet.getString("repair_task_id"),
                resultSet.getString("fault_report_id"),
                resultSet.getString("maintainer_id"),
                RepairReportResult.valueOf(resultSet.getString("result")),
                resultSet.getObject("repaired_at", OffsetDateTime.class),
                resultSet.getString("process_description"),
                resultSet.getString("parts_used"),
                resultSet.getBoolean("requires_reinspection"),
                resultSet.getObject("created_at", OffsetDateTime.class));
    }
}
