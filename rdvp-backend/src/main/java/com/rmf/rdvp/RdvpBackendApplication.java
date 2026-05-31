package com.rmf.rdvp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

import com.rmf.rdvp.config.RdvpRuntimeProperties;

@SpringBootApplication
@EnableConfigurationProperties(RdvpRuntimeProperties.class)
public class RdvpBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(RdvpBackendApplication.class, args);
    }

}
