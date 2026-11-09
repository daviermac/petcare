import { readFileSync } from 'fs';
import { join } from 'path';
import { gerarOpenApi } from '../src/presentation/openapi';

it('docs/openapi.json está atualizado (rode "npm run openapi")', () => {
  const arquivo = JSON.parse(readFileSync(join(__dirname, '../../docs/openapi.json'), 'utf8'));
  const gerado = JSON.parse(JSON.stringify(gerarOpenApi(arquivo.servers)));
  expect(arquivo).toEqual(gerado);
});
