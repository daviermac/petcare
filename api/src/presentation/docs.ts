// Swagger UI da API: GET /docs abre a interface, GET /docs/openapi.json devolve a especificação.
import { onRequest } from 'firebase-functions/v2/https';
import { REGIAO } from './callables';
import { gerarOpenApi } from './openapi';

const SWAGGER_UI = 'https://unpkg.com/swagger-ui-dist@5.17.14';

function servidores() {
  const projeto = process.env.GCLOUD_PROJECT ?? 'demo-petcare';
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    return [{ url: `http://127.0.0.1:5001/${projeto}/${REGIAO}`, description: 'Emulador local' }];
  }
  return [{ url: `https://${REGIAO}-${projeto}.cloudfunctions.net`, description: 'Produção' }];
}

const html = (urlSpec: string) => `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Pet Care API</title>
  <link rel="stylesheet" href="${SWAGGER_UI}/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="${SWAGGER_UI}/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({ url: '${urlSpec}', dom_id: '#swagger-ui', persistAuthorization: true });
  </script>
</body>
</html>`;

export const docs = onRequest({ region: REGIAO }, (req, res) => {
  if (req.path.endsWith('/openapi.json')) {
    res.json(gerarOpenApi(servidores()));
    return;
  }
  // Caminho relativo funciona tanto no emulador quanto em produção.
  const base = req.originalUrl.split('?')[0].replace(/\/$/, '');
  res.type('html').send(html(`${base}/openapi.json`));
});
