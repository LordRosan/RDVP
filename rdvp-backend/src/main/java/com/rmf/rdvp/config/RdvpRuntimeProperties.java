package com.rmf.rdvp.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "rdvp")
public class RdvpRuntimeProperties {

    private final Service service = new Service();

    public Service getService() {
        return service;
    }

    public static class Service {
        private String name = "rdvp-backend";
        private String version = "0.1.0";

        public String getName() {
            return name;
        }

        public void setName(String name) {
            if (name != null && !name.isBlank()) {
                this.name = name;
            }
        }

        public String getVersion() {
            return version;
        }

        public void setVersion(String version) {
            if (version != null && !version.isBlank()) {
                this.version = version;
            }
        }
    }
}
