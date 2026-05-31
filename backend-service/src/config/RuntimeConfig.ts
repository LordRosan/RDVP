export interface RuntimeConfig {
  serviceName: string;
  serviceVersion: string;
  environment: string;
  port: number;
  storageDriver: 'memory';
}

const DEFAULT_PORT = 3000;

export function loadRuntimeConfig(env: NodeJS.ProcessEnv = process.env): RuntimeConfig {
  return {
    serviceName: env.RDVP_SERVICE_NAME?.trim() || 'rdvp-backend-service',
    serviceVersion: env.RDVP_SERVICE_VERSION?.trim() || '0.1.0',
    environment: env.NODE_ENV?.trim() || 'development',
    port: parsePort(env.PORT),
    storageDriver: 'memory'
  };
}

function parsePort(value: string | undefined): number {
  if (value === undefined || value.trim().length === 0) {
    return DEFAULT_PORT;
  }

  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  return port;
}
