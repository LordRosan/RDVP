package com.rmf.rdvp.home.api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.home.HomeDashboardService;
import com.rmf.rdvp.user.AuthenticatedUser;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1/home/dashboard")
@PreAuthorize("isAuthenticated()")
public class HomeDashboardController {

    private final HomeDashboardService homeDashboardService;

    public HomeDashboardController(HomeDashboardService homeDashboardService) {
        this.homeDashboardService = homeDashboardService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<HomeDashboardResponse>> getDashboard(
            @AuthenticationPrincipal AuthenticatedUser user,
            HttpServletRequest request) {
        HomeDashboardResponse response = HomeDashboardResponse.from(homeDashboardService.snapshot(user));
        return ResponseEntity.ok(ApiResponse.success(response, RequestIds.resolve(request)));
    }
}
