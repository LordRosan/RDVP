package com.rmf.rdvp.api.workbench;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.workbench.WorkbenchSummaryService;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1/workbench")
public class WorkbenchController {

    private final WorkbenchSummaryService workbenchSummaryService;

    public WorkbenchController(WorkbenchSummaryService workbenchSummaryService) {
        this.workbenchSummaryService = workbenchSummaryService;
    }

    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<WorkbenchSummaryResponse>> getSummary(
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        var summary = workbenchSummaryService.getSummary(user);
        return ResponseEntity.ok(ApiResponse.success(WorkbenchSummaryResponse.from(summary), RequestIds.resolve(request)));
    }
}
