package com.rmf.rdvp.workbench;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.archive.DeviceChangeRequestRepository;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.operations.OperationsRepository;

@Service
public class WorkbenchSummaryService {

    private final DeviceChangeRequestRepository changeRequestRepository;
    private final OperationsRepository operationsRepository;

    public WorkbenchSummaryService(
            DeviceChangeRequestRepository changeRequestRepository,
            OperationsRepository operationsRepository) {
        this.changeRequestRepository = changeRequestRepository;
        this.operationsRepository = operationsRepository;
    }

    public WorkbenchSummary getSummary(AuthenticatedUser user) {
        return new WorkbenchSummary(
                changeRequestRepository.countPendingReview(),
                operationsRepository.countPendingAcceptanceFaults(),
                operationsRepository.countActiveRepairTasksByMaintainer(user.id()),
                operationsRepository.countPendingReinspections(),
                0);
    }
}
