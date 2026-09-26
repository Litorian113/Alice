import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

// Local checkout only. Deployment secrets still come from the host environment.
export function loadEnvironment() {
  const file = fileURLToPath(new URL('../../.env', import.meta.url));
  if (fs.existsSync(file)) process.loadEnvFile(file);
}
