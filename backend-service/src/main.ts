import { createHttpServer } from './api/server.js';
import { createDefaultAppContext } from './application/AppContext.js';
import { loadRuntimeConfig } from './config/RuntimeConfig.js';

const runtimeConfig = loadRuntimeConfig();
const server = createHttpServer(createDefaultAppContext(runtimeConfig));

server.listen(runtimeConfig.port, () => {
  console.log(`RDVP backend service listening on port ${runtimeConfig.port}`);
});
