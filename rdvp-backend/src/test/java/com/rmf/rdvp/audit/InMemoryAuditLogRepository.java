package com.rmf.rdvp.audit;

import java.util.Comparator;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryAuditLogRepository implements AuditLogRepository {

    private final List<AuditLogRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public void append(AuditLogCreate create) {
        records.add(new AuditLogRecord(
                create.id(),
                create.action(),
                blankToNull(create.targetId()),
                blankToNull(create.targetNo()),
                blankToNull(create.actorId()),
                blankToNull(create.actorName()),
                create.status(),
                blankToNull(create.description()),
                create.occurredAt()));
    }

    @Override
    public AuditLogPage list(AuditLogQuery query) {
        List<AuditLogRecord> filtered = records.stream()
                .filter(record -> query.action() == null || record.action() == query.action())
                .sorted(Comparator.comparing(AuditLogRecord::occurredAt).reversed())
                .toList();
        int offset = Math.max(0, (query.page() - 1) * query.pageSize());
        if (offset >= filtered.size()) {
            return new AuditLogPage(List.of(), filtered.size());
        }

        int toIndex = Math.min(offset + query.pageSize(), filtered.size());
        return new AuditLogPage(filtered.subList(offset, toIndex), filtered.size());
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
