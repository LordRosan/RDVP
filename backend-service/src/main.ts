import { createHttpServer } from './api/server.js';

const port = Number(process.env.PORT ?? 3000);
const server = createHttpServer();

server.listen(port, () => {
  console.log(`RDVP backend service listening on port ${port}`);
});
