package com.rmf.rdvp.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "rdvp")
public class RdvpRuntimeProperties {

    private final Service service = new Service();
    private final QrCode qrCode = new QrCode();

    public Service getService() {
        return service;
    }

    public QrCode getQrCode() {
        return qrCode;
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

    public static class QrCode {
        private String signingSecret = "rdvp-local-development-secret";

        public String getSigningSecret() {
            return signingSecret;
        }

        public void setSigningSecret(String signingSecret) {
            if (signingSecret != null && !signingSecret.isBlank()) {
                this.signingSecret = signingSecret;
            }
        }
    }
}
