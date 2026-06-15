package com.rmf.rdvp.records;

import java.util.ArrayList;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcRecordCenterRepository implements RecordCenterRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcRecordCenterRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public RecordListResponse queryArchiveRecords(String type, String keyword, int limit, int offset) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", limit)
                .addValue("offset", offset);

        if (type != null && !type.isBlank()) {
            conditions.add("cr.request_type = :type");
            parameters.addValue("type", type);
        }
        if (keyword != null && !keyword.isBlank()) {
            conditions.add("(d.device_code ILIKE :keyword OR d.name ILIKE :keyword)");
            parameters.addValue("keyword", "%" + keyword + "%");
        }

        String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);

        List<RecordItemResponse> items = jdbcTemplate.query(
                """
                        SELECT
                            cr.request_type AS record_type,
                            COALESCE(d.device_code, cr.target_device_code) AS device_code,
                            cr.id AS task_no,
                            COALESCE(applicant.username, cr.applicant_id) AS operator_name,
                            COALESCE(cr.initiated_at, cr.created_at) AS occurred_at,
                            cr.status AS business_status,
                            cr.reason AS description,
                            'ARCHIVE' AS record_category
                        FROM device_archive_change_requests cr
                        LEFT JOIN devices d ON d.id = cr.device_id
                        LEFT JOIN users applicant ON applicant.id = cr.applicant_id
                        """
                        + where
                        + " ORDER BY occurred_at DESC"
                        + " LIMIT :limit OFFSET :offset",
                parameters,
                (rs, rowNum) -> new RecordItemResponse(
                        rs.getString("record_category"),
                        rs.getString("record_type"),
                        rs.getString("device_code"),
                        rs.getString("task_no"),
                        rs.getString("operator_name"),
                        rs.getObject("occurred_at", java.time.OffsetDateTime.class),
                        rs.getString("business_status"),
                        rs.getString("description")));
        return new RecordListResponse(items, countRecords(
                "device_archive_change_requests cr LEFT JOIN devices d ON d.id = cr.device_id LEFT JOIN users applicant ON applicant.id = cr.applicant_id",
                where,
                parameters));
    }

    @Override
    public RecordListResponse queryReviewRecords(String type, String keyword, int limit, int offset) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", limit)
                .addValue("offset", offset);

        conditions.add("cr.reviewed_at IS NOT NULL");
        if (type != null && !type.isBlank()) {
            conditions.add("cr.request_type = :type");
            parameters.addValue("type", type);
        }
        if (keyword != null && !keyword.isBlank()) {
            conditions.add("(d.device_code ILIKE :keyword OR d.name ILIKE :keyword)");
            parameters.addValue("keyword", "%" + keyword + "%");
        }

        String where = " WHERE " + String.join(" AND ", conditions);

        List<RecordItemResponse> items = jdbcTemplate.query(
                """
                        SELECT
                            cr.request_type AS record_type,
                            COALESCE(d.device_code, cr.target_device_code) AS device_code,
                            cr.id AS task_no,
                            COALESCE(reviewer.username, applicant.username, cr.reviewer_id, cr.applicant_id) AS operator_name,
                            cr.reviewed_at AS occurred_at,
                            cr.status AS business_status,
                            cr.review_comment AS description,
                            'REVIEW' AS record_category
                        FROM device_archive_change_requests cr
                        LEFT JOIN devices d ON d.id = cr.device_id
                        LEFT JOIN users applicant ON applicant.id = cr.applicant_id
                        LEFT JOIN users reviewer ON reviewer.id = cr.reviewer_id
                        """
                        + where
                        + " ORDER BY occurred_at DESC"
                        + " LIMIT :limit OFFSET :offset",
                parameters,
                (rs, rowNum) -> new RecordItemResponse(
                        rs.getString("record_category"),
                        rs.getString("record_type"),
                        rs.getString("device_code"),
                        rs.getString("task_no"),
                        rs.getString("operator_name"),
                        rs.getObject("occurred_at", java.time.OffsetDateTime.class),
                        rs.getString("business_status"),
                        rs.getString("description")));
        return new RecordListResponse(items, countRecords(
                "device_archive_change_requests cr LEFT JOIN devices d ON d.id = cr.device_id LEFT JOIN users applicant ON applicant.id = cr.applicant_id LEFT JOIN users reviewer ON reviewer.id = cr.reviewer_id",
                where,
                parameters));
    }

    @Override
    public RecordListResponse queryOperationsRecords(String type, String keyword, int limit, int offset) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", limit)
                .addValue("offset", offset);

        List<String> keywordConditions = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            keywordConditions.add("(d.device_code ILIKE :keyword OR d.name ILIKE :keyword)");
            parameters.addValue("keyword", "%" + keyword + "%");
        }

        StringBuilder sql = new StringBuilder();

        // device_verification_records
        {
            List<String> conditions = new ArrayList<>(keywordConditions.stream()
                    .map(c -> c.replace("d.", "dvrd.")).toList());
            String filter = (type == null || type.isBlank() || "DEVICE_VERIFICATION".equalsIgnoreCase(type))
                    ? ""
                    : "1=0";
            if (!filter.isBlank()) {
                conditions.add(filter);
            }
            String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
            sql.append("""
                    SELECT
                        'DEVICE_VERIFICATION' AS record_type,
                        dvrd.device_code,
                        dvr.id AS task_no,
                        COALESCE(operator.username, dvr.operator_id) AS operator_name,
                        dvr.verified_at AS occurred_at,
                        dvr.result AS business_status,
                        dvr.description,
                        'OPERATIONS' AS record_category
                    FROM device_verification_records dvr
                    JOIN devices dvrd ON dvrd.id = dvr.device_id
                    LEFT JOIN users operator ON operator.id = dvr.operator_id
                    """);
            sql.append(where);
        }

        sql.append(" UNION ALL ");

        // fault_reports
        {
            List<String> conditions = new ArrayList<>(keywordConditions.stream()
                    .map(c -> c.replace("d.", "frd.")).toList());
            String filter = (type == null || type.isBlank() || "FAULT_REPORT".equalsIgnoreCase(type))
                    ? ""
                    : "1=0";
            if (!filter.isBlank()) {
                conditions.add(filter);
            }
            String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
            sql.append("""
                    SELECT
                        'FAULT_REPORT' AS record_type,
                        frd.device_code,
                        fr.fault_report_no AS task_no,
                        COALESCE(reporter.username, fr.reporter_id) AS operator_name,
                        fr.occurred_at,
                        fr.status AS business_status,
                        fr.description,
                        'OPERATIONS' AS record_category
                    FROM fault_reports fr
                    JOIN devices frd ON frd.id = fr.device_id
                    LEFT JOIN users reporter ON reporter.id = fr.reporter_id
                    """);
            sql.append(where);
        }

        sql.append(" UNION ALL ");

        // repair_tasks
        {
            List<String> conditions = new ArrayList<>(keywordConditions.stream()
                    .map(c -> c.replace("d.", "rtd.")).toList());
            String filter = (type == null || type.isBlank() || "REPAIR_TASK_ACCEPT".equalsIgnoreCase(type))
                    ? ""
                    : "1=0";
            if (!filter.isBlank()) {
                conditions.add(filter);
            }
            String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
            sql.append("""
                    SELECT
                        'REPAIR_TASK_ACCEPT' AS record_type,
                        rtd.device_code,
                        rt.repair_task_no AS task_no,
                        COALESCE(maintainer.username, rt.maintainer_id) AS operator_name,
                        rt.accepted_at AS occurred_at,
                        rt.status AS business_status,
                        '' AS description,
                        'OPERATIONS' AS record_category
                    FROM repair_tasks rt
                    JOIN fault_reports frt ON frt.id = rt.fault_report_id
                    JOIN devices rtd ON rtd.id = frt.device_id
                    LEFT JOIN users maintainer ON maintainer.id = rt.maintainer_id
                    """);
            sql.append(where);
        }

        sql.append(" UNION ALL ");

        // repair_reports
        {
            List<String> conditions = new ArrayList<>(keywordConditions.stream()
                    .map(c -> c.replace("d.", "rrd.")).toList());
            String filter = (type == null || type.isBlank() || "REPAIR_REPORT".equalsIgnoreCase(type))
                    ? ""
                    : "1=0";
            if (!filter.isBlank()) {
                conditions.add(filter);
            }
            String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
            sql.append("""
                    SELECT
                        'REPAIR_REPORT' AS record_type,
                        rrd.device_code,
                        rr.repair_report_no AS task_no,
                        COALESCE(maintainer.username, rr.maintainer_id) AS operator_name,
                        rr.repaired_at AS occurred_at,
                        rr.result AS business_status,
                        rr.process_description AS description,
                        'OPERATIONS' AS record_category
                    FROM repair_reports rr
                    JOIN fault_reports frr ON frr.id = rr.fault_report_id
                    JOIN devices rrd ON rrd.id = frr.device_id
                    LEFT JOIN users maintainer ON maintainer.id = rr.maintainer_id
                    """);
            sql.append(where);
        }

        sql.append(" UNION ALL ");

        // reinspection_records
        {
            List<String> conditions = new ArrayList<>(keywordConditions.stream()
                    .map(c -> c.replace("d.", "rid.")).toList());
            String filter = (type == null || type.isBlank() || "REINSPECTION_RECORD".equalsIgnoreCase(type))
                    ? ""
                    : "1=0";
            if (!filter.isBlank()) {
                conditions.add(filter);
            }
            String where = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
            sql.append("""
                    SELECT
                        'REINSPECTION_RECORD' AS record_type,
                        rid.device_code,
                        ri.reinspection_record_no AS task_no,
                        COALESCE(reinspector.username, ri.reinspector_id) AS operator_name,
                        ri.reinspected_at AS occurred_at,
                        ri.result AS business_status,
                        ri.description,
                        'OPERATIONS' AS record_category
                    FROM reinspection_records ri
                    JOIN fault_reports fir ON fir.id = ri.fault_report_id
                    JOIN devices rid ON rid.id = fir.device_id
                    LEFT JOIN users reinspector ON reinspector.id = ri.reinspector_id
                    """);
            sql.append(where);
        }

        String unionSql = sql.toString();
        String pagedSql = "SELECT * FROM (" + unionSql + ") records"
                + " ORDER BY occurred_at DESC"
                + " LIMIT :limit OFFSET :offset";

        List<RecordItemResponse> items = jdbcTemplate.query(
                pagedSql,
                parameters,
                (rs, rowNum) -> new RecordItemResponse(
                        rs.getString("record_category"),
                        rs.getString("record_type"),
                        rs.getString("device_code"),
                        rs.getString("task_no"),
                        rs.getString("operator_name"),
                        rs.getObject("occurred_at", java.time.OffsetDateTime.class),
                        rs.getString("business_status"),
                        rs.getString("description")));
        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM (" + unionSql + ") records",
                parameters,
                Long.class);
        return new RecordListResponse(items, total == null ? 0 : total);
    }

    private long countRecords(String fromClause, String whereClause, MapSqlParameterSource parameters) {
        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + fromClause + whereClause,
                parameters,
                Long.class);
        return total == null ? 0 : total;
    }
}
