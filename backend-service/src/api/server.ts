import { createServer, Server } from 'node:http';
import { AppContext, createDefaultAppContext } from '../application/AppContext.js';
import { handleApiRequest } from './routes.js';

export function createHttpServer(appContext: AppContext = createDefaultAppContext()): Server {
  return createServer((request, response) => {
    void handleApiRequest(appContext, request, response);
  });
}
