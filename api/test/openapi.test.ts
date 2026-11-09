import { readFileSync } from 'fs';
import { join } from 'path';
import { gerarOpenApi, NOMES_OPERACOES } from '../src/presentation/openapi';

describe('OpenAPI (Swagger)', () => {
  it('documenta exatamente as Callable Functions exportadas', () => {
    const fonte = readFileSync(join(__dirname, '../src/presentation/callables.ts'), 'utf8');
    const callables = [...fonte.matchAll(/export const (\w+) = onCall\(/g)].map((m) => m[1]);
    expect([...NOMES_OPERACOES].sort()).toEqual(callables.sort());
  });

  it('gera um documento OpenAPI 3 com POST, corpo { data } e segurança', () => {
    const spec = gerarOpenApi([{ url: 'http://localhost', description: 'teste' }]) as any;
    expect(spec.openapi).toMatch(/^3\./);
    for (const nome of NOMES_OPERACOES) {
      const op = spec.paths[`/${nome}`].post;
      expect(op.operationId).toBe(nome);
      expect(op.requestBody.content['application/json'].schema.required).toEqual(['data']);
      expect(op.responses['200']).toBeDefined();
    }
    expect(spec.components.securitySchemes.firebaseIdToken.scheme).toBe('bearer');
  });

  it('todas as referências $ref apontam para schemas existentes', () => {
    const spec = gerarOpenApi([]) as any;
    const refs = JSON.stringify(spec).match(/#\/components\/schemas\/\w+/g) ?? [];
    for (const r of refs) expect(spec.components.schemas[r.split('/').pop()!]).toBeDefined();
  });
});
