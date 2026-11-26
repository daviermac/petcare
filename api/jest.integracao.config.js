/** Testes de integração: precisam dos emuladores rodando e do seed (ver integracao/fluxos.test.ts). */
/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/integracao'],
};
