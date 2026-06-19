package com.rmf.rdvp.api.dashboard;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.dashboard.DashboardService;
import com.rmf.rdvp.identity.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1/dashboard")
@PreAuthorize("isAuthenticated()")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<DashboardResponse>> getDashboard(
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        DashboardResponse response = DashboardResponse.from(dashboardService.snapshot(user));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }
}
