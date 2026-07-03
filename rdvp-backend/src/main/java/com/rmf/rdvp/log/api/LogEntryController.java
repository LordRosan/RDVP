package com.rmf.rdvp.log.api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.log.LogEntryService;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1/log-entries")
public class LogEntryController {

    private final LogEntryService logEntryService;

    public LogEntryController(LogEntryService logEntryService) {
        this.logEntryService = logEntryService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY','LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY')")
    public ResponseEntity<ApiResponse<LogEntryListResponse>> list(
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            HttpServletRequest request) {
        var result = logEntryService.list(action, keyword, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(LogEntryListResponse.from(result), RequestIds.resolve(request)));
    }
}

