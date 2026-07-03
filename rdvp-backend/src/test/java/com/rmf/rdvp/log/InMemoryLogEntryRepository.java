package com.rmf.rdvp.log;

import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryLogEntryRepository implements LogEntryRepository {

    private final List<LogEntry> records = new CopyOnWriteArrayList<>();

    @Override
    public void append(LogEntryCreate create) {
        records.add(new LogEntry(
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
    public LogEntryPage list(LogEntryQuery query) {
        List<LogEntry> filtered = records.stream()
                .filter(record -> query.action() == null || record.action() == query.action())
                .filter(record -> query.keyword() == null || containsKeyword(record, query.keyword()))
                .sorted(Comparator.comparing(LogEntry::occurredAt).reversed())
                .toList();
        int offset = Math.max(0, (query.page() - 1) * query.pageSize());
        if (offset >= filtered.size()) {
            return new LogEntryPage(List.of(), filtered.size());
        }

        int toIndex = Math.min(offset + query.pageSize(), filtered.size());
        return new LogEntryPage(filtered.subList(offset, toIndex), filtered.size());
    }

    @Override
    public long countSuccessByAction(LogAction action) {
        return records.stream()
                .filter(record -> record.action() == action)
                .filter(record -> record.status() == LogEntryStatus.SUCCESS)
                .count();
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }

    private boolean containsKeyword(LogEntry record, String keyword) {
        String normalizedKeyword = keyword.toLowerCase(Locale.ROOT);
        return contains(record.targetId(), normalizedKeyword)
                || contains(record.targetNo(), normalizedKeyword)
                || contains(record.actorName(), normalizedKeyword)
                || contains(record.description(), normalizedKeyword);
    }

    private boolean contains(String value, String normalizedKeyword) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(normalizedKeyword);
    }
}
