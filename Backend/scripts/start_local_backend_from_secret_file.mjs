import fs from 'node:fs';

const secretPath = process.env.OPENAI_API_KEY_FILE;
if (secretPath) {
  const apiKey = fs.readFileSync(secretPath, 'utf8').trim();
  fs.rmSync(secretPath, { force: true });
  process.env.OPENAI_API_KEY = apiKey;
  delete process.env.OPENAI_API_KEY_FILE;
}

await import('../src/server.mjs');
