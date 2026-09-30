#!/usr/bin/env node
// Development-only provisioning. No host-runtime dependencies or implicit trust changes.
import { spawnSync } from 'node:child_process';
import { X509Certificate, createPrivateKey, createPublicKey } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync, chmodSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { networkInterfaces } from 'node:os';
import { isIP } from 'node:net';

export function namesFor(ip, hostname = '') {
  if (isIP(ip) !== 4 || ip === '0.0.0.0') throw new Error('Specify the reachable host IPv4 address with --ip (see the lobby address picker or the ips command).');
  if (hostname && !/^[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}$/.test(hostname)) throw new Error('Hostname must contain only letters, digits, dots and hyphens.');
  return [...new Set([ip, ...(hostname ? [hostname] : []), 'localhost', '127.0.0.1'])];
}
export function validateLeaf(certificate, privateKey, names, now = Date.now()) {
  const leaf = new X509Certificate(certificate);
  if (Date.parse(leaf.validFrom) > now || Date.parse(leaf.validTo) <= now + 7 * 86400000) throw new Error('Certificate is not valid now or expires within seven days.');
  const publicKey = createPublicKey(createPrivateKey(privateKey)).export({ type: 'spki', format: 'der' });
  if (!publicKey.equals(leaf.publicKey.export({ type: 'spki', format: 'der' }))) throw new Error('Certificate and private key do not match.');
  for (const name of names) if (!(isIP(name) ? leaf.checkIP(name) : leaf.checkHost(name))) throw new Error(`Certificate does not cover ${name}.`);
  return leaf;
}

async function main() {
  const [command = 'help', ...args] = process.argv.slice(2);
  const options = {};
  for (let index = 0; index < args.length; index++) {
    const key = args[index];
    if (!['--ip', '--hostname', '--dir', '--mkcert', '--advertise-hostname'].includes(key)) throw new Error(`Unknown option ${key}`);
    options[key] = key === '--advertise-hostname' ? true : args[++index];
    if (!options[key]) throw new Error(`Missing value for ${key}`);
  }
  const root = fileURLToPath(new URL('../', import.meta.url));
  const directory = resolve(options['--dir'] || join(root, 'local'));
  const caDirectory = join(directory, 'ca');
  const configPath = join(directory, 'network.json');
  const config = existsSync(configPath) ? JSON.parse(readFileSync(configPath, 'utf8')) : {};
  const executable = options['--mkcert'] || (existsSync(join(root, 'local/tools/mkcert' + (process.platform === 'win32' ? '.exe' : ''))) ? join(root, 'local/tools/mkcert' + (process.platform === 'win32' ? '.exe' : '')) : 'mkcert');
  const run = args => {
    const result = spawnSync(executable, args, { shell: false, windowsHide: true, stdio: 'inherit', env: { ...process.env, CAROOT: caDirectory } });
    if (result.error) throw new Error(`mkcert is unavailable. Run the download command or install mkcert from its official releases. ${result.error.message}`);
    if (result.status !== 0) throw new Error(`mkcert failed (${result.status}).`);
  };
  const writeConfig = value => { writeFileSync(configPath + '.tmp', JSON.stringify(value, null, 2) + '\n', { mode: 0o600 }); renameSync(configPath + '.tmp', configPath); };
  if (command === 'ips') {
    for (const [adapter, addresses] of Object.entries(networkInterfaces())) for (const address of addresses || []) if (address.family === 'IPv4' && !address.internal && !address.address.startsWith('169.254.')) console.log(`${adapter}: ${address.address}`);
    return;
  }
  if (command === 'download') {
    const platform = { win32: 'windows', linux: 'linux', darwin: 'darwin' }[process.platform];
    const architecture = { x64: 'amd64', arm64: 'arm64' }[process.arch];
    if (!platform || !architecture) throw new Error('Download a supported mkcert binary manually from its official release.');
    const name = `mkcert-v1.4.4-${platform}-${architecture}${platform === 'windows' ? '.exe' : ''}`;
    const url = `https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/${name}`;
    console.log(`Downloading the official mkcert v1.4.4 development tool: ${url}. No installation or trust changes.`);
    const response = await fetch(url); if (!response.ok) throw new Error(`Download failed: ${response.status}`);
    const tools = join(root, 'local/tools'); mkdirSync(tools, { recursive: true }); writeFileSync(join(root, 'local/.gdignore'), '');
    const target = join(tools, 'mkcert' + (platform === 'windows' ? '.exe' : ''));
    writeFileSync(target, Buffer.from(await response.arrayBuffer()), { mode: 0o700 }); chmodSync(target, 0o700);
    console.log(`Saved ${target}`); return;
  }
  if (command === 'status') { console.log(JSON.stringify(config, null, 2)); console.log(`Public CA: ${join(directory, 'Play-Shapes-Dev-CA.cer')}`); return; }
  if (!['setup', 'regenerate', 'disable', 'trust', 'untrust'].includes(command)) {
    console.log('Commands: ips | download | setup --ip LAN_IP [--hostname playshapes.local] | regenerate --ip LAN_IP | disable | trust | untrust | status\nOptions: --dir DIRECTORY --mkcert EXECUTABLE --advertise-hostname\nsetup/regenerate never change system trust. trust/untrust explicitly change ONLY this development CA. Restart Godot after configuration changes.'); return;
  }
  mkdirSync(directory, { recursive: true, mode: 0o700 }); writeFileSync(join(directory, '.gdignore'), '');
  if (command === 'disable') { writeConfig({ ...config, tls_enabled: false }); console.log('Secure mode disabled. Restart the host. Certificates and trust are unchanged.'); return; }
  if (command === 'trust' || command === 'untrust') {
    if (!existsSync(join(caDirectory, 'rootCA.pem'))) throw new Error('Run setup before changing trust.');
    console.log(`${command === 'trust' ? 'INSTALLING' : 'REMOVING'} this Play Shapes development root in the host trust stores. This is an explicit system trust change; mkcert may request elevation.`);
    run([command === 'trust' ? '-install' : '-uninstall']); return;
  }
  const ip = options['--ip']; const hostname = options['--hostname'] || '';
  const names = namesFor(ip, hostname);
  if (options['--advertise-hostname'] && !hostname) throw new Error('--advertise-hostname requires --hostname and working external LAN name discovery.');
  const certificatePath = join(directory, 'certificate.pem'), privateKeyPath = join(directory, 'key.pem');
  let reuse = command === 'setup' && existsSync(certificatePath) && existsSync(privateKeyPath) && existsSync(join(caDirectory, 'rootCA.pem'));
  if (reuse) { try { const leaf = validateLeaf(readFileSync(certificatePath), readFileSync(privateKeyPath), names); if (!leaf.verify(new X509Certificate(readFileSync(join(caDirectory, 'rootCA.pem'))).publicKey)) reuse = false; } catch { reuse = false; } }
  if (!reuse) {
    mkdirSync(caDirectory, { recursive: true, mode: 0o700 });
    run(['-cert-file', certificatePath + '.tmp', '-key-file', privateKeyPath + '.tmp', ...names]);
    validateLeaf(readFileSync(certificatePath + '.tmp'), readFileSync(privateKeyPath + '.tmp'), names);
    renameSync(certificatePath + '.tmp', certificatePath); renameSync(privateKeyPath + '.tmp', privateKeyPath); chmodSync(privateKeyPath, 0o600);
  }
  const rootCA = new X509Certificate(readFileSync(join(caDirectory, 'rootCA.pem')));
  writeFileSync(join(directory, 'Play-Shapes-Dev-CA.cer'), rootCA.raw);
  writeConfig({ ...config, tls_enabled: true, bind_address: '*', advertised_host: options['--advertise-hostname'] ? hostname : ip, http_port: config.http_port || 8080, websocket_port: config.websocket_port || 8081, certificate_path: 'certificate.pem', private_key_path: 'key.pem' });
  console.log(`${reuse ? 'Reused valid certificate' : 'Generated certificate'} for ${names.join(', ')}. Restart the host.\nTrust has NOT been changed. Transfer only Play-Shapes-Dev-CA.cer to controlled phones; NEVER share ca/rootCA-key.pem or key.pem.\nRoot SHA-256: ${rootCA.fingerprint256}\nName discovery is not installed; use the configured IP unless you have verified hostname resolution on every test phone.`);
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(error => { console.error(error.message); process.exitCode = 1; });
