package com.rmf.rdvp.api.audit;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.audit.AuditLogService;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1/audit-logs")
public class AuditLogController {

    private final AuditLogService auditLogService;

    public AuditLogController(AuditLogService auditLogService) {
        this.auditLogService = auditLogService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('MANAGEMENT_CENTER_RECORD_QUERY')")
    public ResponseEntity<ApiResponse<AuditLogListResponse>> list(
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            HttpServletRequest request) {
        var result = auditLogService.list(action, keyword, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(AuditLogListResponse.from(result), RequestIds.resolve(request)));
    }
}

