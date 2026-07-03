package com.rmf.rdvp.log;

public interface LogEntryRepository {

    void append(LogEntryCreate create);

    LogEntryPage list(LogEntryQuery query);

    long countSuccessByAction(LogAction action);
}
