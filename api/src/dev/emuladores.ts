// Inicia os emuladores do Firebase guardando os dados entre uma execução e outra.
// Uso: npm run emuladores   (na pasta api/)
// Os dados ficam em .emulador/ na raiz do repositório (fora do Git).
import { spawn } from 'child_process';
import { existsSync } from 'fs';
import { join } from 'path';

const raiz = join(__dirname, '..', '..', '..');
const pastaDados = '.emulador';

const args = ['emulators:start', `--export-on-exit=${pastaDados}`];
if (existsSync(join(raiz, pastaDados))) args.push(`--import=${pastaDados}`);
else console.log('Primeira execução: começando com o banco vazio. Rode "npm run seed" em outro terminal para criar os dados de exemplo.\n');

const proc = spawn('firebase', args, { cwd: raiz, stdio: 'inherit', shell: process.platform === 'win32' });
proc.on('exit', (codigo) => process.exit(codigo ?? 0));
// O Ctrl+C do terminal já chega no Firebase, que salva os dados e fecha.
// Este processo só espera (repassar o sinal faria o Firebase sair sem salvar).
process.on('SIGINT', () => undefined);
