#!/usr/bin/env bash
# VETO — Render fix: bundle engine with esbuild so plain node runs it
# Run from the root of your veto folder:  bash apply-render-fix.sh
set -e
echo "Applying Render fix ..."
# ---------- apps/engine/package.json ----------
cat > apps/engine/package.json << 'VETO_FILE_1_END_9f3a'
{
  "name": "@veto/engine",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "esbuild src/index.ts --bundle --platform=node --target=node20 --format=esm --outfile=dist/index.js --banner:js=\"import{createRequire}from'module';const require=createRequire(import.meta.url);\"",
    "start": "node dist/index.js",
    "test": "vitest run",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@fastify/cors": "^9.0.1",
    "ethers": "^6.13.2",
    "fastify": "^4.28.1",
    "ioredis": "^5.4.1",
    "viem": "^2.55.0"
  },
  "devDependencies": {
    "@types/node": "^20.16.5",
    "esbuild": "^0.28.1",
    "tsx": "^4.19.1",
    "typescript": "^5.6.2",
    "vitest": "^2.1.1"
  }
}
VETO_FILE_1_END_9f3a

echo "Installing esbuild ..."
npm install
echo ""
echo "Done. Testing the production build locally ..."
npm run engine:build
echo ""
echo "Build complete. Commit + push, then Render will redeploy and boot cleanly:"
echo "  git add ."
echo "  git commit -m \"fix: bundle engine for node runtime (Render)\""
echo "  git push"
