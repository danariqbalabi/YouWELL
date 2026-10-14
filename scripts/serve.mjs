import http from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || 'build/web');
const port = Number(process.env.PORT || 8080);
if (!existsSync(path.join(root, 'index.html'))) {
  console.error('Build belum tersedia. Jalankan bash scripts/preview.sh.'); process.exit(1);
}
const types = {'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf','.otf':'font/otf','.css':'text/css'};
http.createServer((req, res) => {
  let route;
  try { route = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch { res.writeHead(400).end(); return; }
  const file = path.resolve(root, '.' + route);
  if (file !== root && !file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  const target = existsSync(file) && statSync(file).isFile() ? file : path.join(root, 'index.html');
  res.writeHead(200, {'Content-Type':types[path.extname(target)] || 'application/octet-stream', 'Cache-Control':'no-store'});
  createReadStream(target).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`YouWell preview siap: http://localhost:${port}`));
