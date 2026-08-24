# Portas do Sunshine por emulador

Todos os 9 pods rodam com `hostNetwork: true` no unico node com GPU
(`moltres`), entao o IP e sempre o mesmo - so a porta muda por emulador.

- **IP do node (moltres):** `192.168.1.122`
- Cada emulador usa uma porta base (`sunshine.port` em
  `values/gaming/<emulador>.yaml`) - todas as outras portas do Sunshine
  sao offsets FIXOS a partir dela (confirmado no codigo fonte do
  Sunshine, `net::map_port()`): `https = base-5`, `web UI = base+1`,
  `video = base+9`, `control = base+10`, `audio = base+11`, `mic = base+13`,
  `rtsp = base+21`.
- A porta base em si e o **HTTP** (usado so pro pareamento inicial via PIN).

## Tabela completa

| Emulador | Porta base (HTTP) | HTTPS | Web UI | RTSP | Video (UDP) | Control (UDP) | Audio (UDP) | Mic (UDP) |
|----------|-------------------:|------:|-------:|-----:|------------:|---------------:|------------:|----------:|
| Dolphin  | 47989 | 47984 | 47990 | 48010 | 47998 | 47999 | 48000 | 48002 |
| Azahar   | 48089 | 48084 | 48090 | 48110 | 48098 | 48099 | 48100 | 48102 |
| PCSX2    | 48189 | 48184 | 48190 | 48210 | 48198 | 48199 | 48200 | 48202 |
| RPCS3    | 48289 | 48284 | 48290 | 48310 | 48298 | 48299 | 48300 | 48302 |
| Xemu     | 48389 | 48384 | 48390 | 48410 | 48398 | 48399 | 48400 | 48402 |
| Flycast  | 48489 | 48484 | 48490 | 48510 | 48498 | 48499 | 48500 | 48502 |
| Eden     | 48589 | 48584 | 48590 | 48610 | 48598 | 48599 | 48600 | 48602 |
| PPSSPP   | 48689 | 48684 | 48690 | 48710 | 48698 | 48699 | 48700 | 48702 |
| shadPS4  | 48789 | 48784 | 48790 | 48810 | 48798 | 48799 | 48800 | 48802 |

## Web UI via Traefik (HTTPS, porta 443)

A Web UI (config/pareamento) de cada emulador tambem fica exposta pelo
Traefik via `IngressRoute` (chart `charts/gaming-sunshine-webui/`), sem
precisar saber a porta - so o hostname:

| Emulador | Hostname |
|----------|----------|
| Dolphin  | `dolphin-sunshine.henriqzimer.com.br` |
| Azahar   | `azahar-sunshine.henriqzimer.com.br` |
| PCSX2    | `pcsx2-sunshine.henriqzimer.com.br` |
| RPCS3    | `rpcs3-sunshine.henriqzimer.com.br` |
| Xemu     | `xemu-sunshine.henriqzimer.com.br` |
| Flycast  | `flycast-sunshine.henriqzimer.com.br` |
| Eden     | `eden-sunshine.henriqzimer.com.br` |
| PPSSPP   | `ppsspp-sunshine.henriqzimer.com.br` |
| shadPS4  | `shadps4-sunshine.henriqzimer.com.br` |

Requer entrada de DNS local (Pi-hole) apontando cada hostname pro IP do
Traefik LoadBalancer (`192.168.1.150`) - ainda nao configurado.

## Moonlight

O Moonlight conecta direto no IP do node (`192.168.1.122`) + porta base
(HTTP) de cada emulador - o app descobre as outras portas sozinho a
partir dai. Cada emulador aparece na lista de PCs do Moonlight com o
nome configurado em `sunshine_name` (Dolphin, Azahar, PCSX2, RPCS3,
Xemu, Flycast, Eden, PPSSPP, shadPS4).
