<div align="center">

# socksctl

**Persistent SSH SOCKS5 tunnel — one command setup**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-orange)](https://ubuntu.com)
[![Debian](https://img.shields.io/badge/Debian-11%2B-red)](https://debian.org)

**Language / Язык:** [English](#english) · [Русский](#русский)

</div>

---

<p align="center">
  <img src="pic1.png" alt="socksctl installer in terminal" width="720">
</p>

<p align="center">
  <sub>Interactive installer: enter VPS IP and password — get <code>socks5h://127.0.0.1:1080</code></sub>
</p>

---

<a id="english"></a>

## English

### What is socksctl?

**socksctl** is a small CLI tool that sets up a **persistent SOCKS5 proxy** on your Linux server through an **SSH tunnel** to an external VPS.

You run one command, enter the **IP** and **password** of your foreign VPS once — socksctl handles everything else:

- installs dependencies (`autossh`, `openssh-client`, …)
- generates an SSH key
- copies the key to the VPS
- creates a **systemd** service with autostart
- verifies the proxy works

**Result:** `socks5h://127.0.0.1:1080` — stable internet exit through your VPS.

**Typical use cases:**

- Access **Telegram Bot API** and other services blocked in your region
- Route server traffic through a foreign IP without a VPN interface
- Quick setup for bots, scrapers, and backend services on Ubuntu/Debian

### How it works

```text
Your app  →  127.0.0.1:1080 (SOCKS5)  →  SSH tunnel  →  VPS  →  Internet
```

> No new network interface is created — only a local port. After reboot the tunnel starts automatically.

### Quick install (one command)

Works on a clean Ubuntu/Debian server as **root**:

```bash
bash -c 'd=$(mktemp -d); curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz | tar xz -C "$d" --strip-components=1; exec bash "$d/install.sh"'
```

Then enter:

1. **External VPS IP** (e.g. `185.242.247.214`)
2. **root password** (once, not stored)

**Alternative** (unstable network — download first):

```bash
curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 \
  -o /tmp/socksctl.tgz \
  https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz \
  && mkdir -p /tmp/socksctl-src \
  && tar xzf /tmp/socksctl.tgz -C /tmp/socksctl-src --strip-components=1 \
  && bash /tmp/socksctl-src/install.sh
```

**With sudo** (non-root user):

```bash
sudo bash -c 'd=$(mktemp -d); curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz | tar xz -C "$d" --strip-components=1; exec bash "$d/install.sh"'
```

**Git clone:**

```bash
git clone https://github.com/Taurus-Silvr/socksctl.git
cd socksctl && bash install.sh
```

<details>
<summary><strong>⚠️ Why not <code>curl | sudo bash</code>?</strong></summary>

`sudo` breaks the pipe stdin — the install may hang with no output. Use the commands above instead.

`raw.githubusercontent.com` may also timeout in some regions — the recommended command uses **github.com archive** only.

</details>

### Verify

```bash
# External IP via proxy (should match your VPS)
curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me

# Telegram API (often blocked without proxy)
curl --socks5-hostname 127.0.0.1:1080 https://api.telegram.org

sudo socksctl status
sudo socksctl doctor
```

### Commands

| Command | Description |
|---------|-------------|
| `sudo socksctl install` | Interactive setup / reinstall |
| `sudo socksctl status` | Service status and SOCKS5 address |
| `sudo socksctl restart` | Restart tunnel |
| `sudo socksctl logs` | Live logs (`journalctl -f`) |
| `sudo socksctl doctor` | Full diagnostics |
| `sudo socksctl uninstall` | Remove service and config |

### App examples

**curl:**

```bash
curl --socks5-hostname 127.0.0.1:1080 https://api.telegram.org/bot<TOKEN>/getMe
```

**Python:**

```python
proxies = {
    "http": "socks5h://127.0.0.1:1080",
    "https": "socks5h://127.0.0.1:1080",
}
```

**Environment:**

```bash
export ALL_PROXY=socks5h://127.0.0.1:1080
```

### Requirements

| | |
|---|---|
| **Local server** | Ubuntu 20.04 / 22.04 / 24.04 or Debian 11+, root or sudo |
| **External VPS** | SSH (`sshd`), password login for `root` (or `--user`), port 22 open |

### Security

- Password is **never** saved to disk
- Dedicated SSH key: `/root/.ssh/socksctl_key`
- Config: `/etc/socksctl/config.env` (no secrets)
- Warning when binding to `0.0.0.0`

### License

MIT — see [LICENSE](LICENSE).

---

<a id="русский"></a>

## Русский

### Что такое socksctl?

**socksctl** — утилита для настройки **постоянного SOCKS5-прокси** на Linux-сервере через **SSH-туннель** на зарубежный VPS.

Запускаете одну команду, один раз вводите **IP** и **пароль** VPS — всё остальное делает socksctl:

- ставит зависимости (`autossh`, `openssh-client`, …)
- создаёт SSH-ключ
- добавляет ключ на VPS
- настраивает **systemd** с автозапуском
- проверяет, что прокси работает

**Результат:** `socks5h://127.0.0.1:1080` — стабильный выход в интернет через ваш VPS.

**Зачем это нужно:**

- Доступ к **Telegram Bot API** и другим сервисам, заблокированным в РФ
- Выход в интернет с сервера через зарубежный IP без VPN-интерфейса
- Быстрая настройка для ботов, парсеров и backend на Ubuntu/Debian

### Как это работает

```text
Приложение  →  127.0.0.1:1080 (SOCKS5)  →  SSH-туннель  →  VPS  →  Интернет
```

> Новый сетевой интерфейс **не создаётся** — только локальный порт. После reboot туннель поднимается сам.

### Быстрая установка (одна команда)

На чистой Ubuntu/Debian под **root**:

```bash
bash -c 'd=$(mktemp -d); curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz | tar xz -C "$d" --strip-components=1; exec bash "$d/install.sh"'
```

Дальше:

1. **IP внешнего VPS** (например `185.242.247.214`)
2. **Пароль root** (один раз, не сохраняется)

**Альтернатива** (нестабильная сеть — сначала скачать):

```bash
curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 \
  -o /tmp/socksctl.tgz \
  https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz \
  && mkdir -p /tmp/socksctl-src \
  && tar xzf /tmp/socksctl.tgz -C /tmp/socksctl-src --strip-components=1 \
  && bash /tmp/socksctl-src/install.sh
```

**С sudo** (если не root):

```bash
sudo bash -c 'd=$(mktemp -d); curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz | tar xz -C "$d" --strip-components=1; exec bash "$d/install.sh"'
```

**Git clone:**

```bash
git clone https://github.com/Taurus-Silvr/socksctl.git
cd socksctl && bash install.sh
```

<details>
<summary><strong>⚠️ Почему не работает <code>curl | sudo bash</code>?</strong></summary>

`sudo` перехватывает stdin из pipe — установка «зависает» без вывода. Используйте команды выше.

`raw.githubusercontent.com` в РФ часто таймаутит по SSL — рекомендуемая команда качает архив только с **github.com**.

</details>

### Проверка

```bash
# IP через прокси (должен совпадать с VPS)
curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me

# Telegram API (без прокси в РФ обычно не открывается)
curl --socks5-hostname 127.0.0.1:1080 https://api.telegram.org

sudo socksctl status
sudo socksctl doctor
```

### Команды

| Команда | Описание |
|---------|----------|
| `sudo socksctl install` | Интерактивная установка / переустановка |
| `sudo socksctl status` | Статус сервиса и адрес SOCKS5 |
| `sudo socksctl restart` | Перезапуск туннеля |
| `sudo socksctl logs` | Логи в реальном времени |
| `sudo socksctl doctor` | Полная диагностика |
| `sudo socksctl uninstall` | Удаление сервиса и конфига |

### Примеры для приложений

**curl:**

```bash
curl --socks5-hostname 127.0.0.1:1080 https://api.telegram.org/bot<TOKEN>/getMe
```

**Python:**

```python
proxies = {
    "http": "socks5h://127.0.0.1:1080",
    "https": "socks5h://127.0.0.1:1080",
}
```

**Переменные окружения:**

```bash
export ALL_PROXY=socks5h://127.0.0.1:1080
```

### Требования

| | |
|---|---|
| **Локальный сервер** | Ubuntu 20.04 / 22.04 / 24.04 или Debian 11+, root или sudo |
| **Внешний VPS** | SSH (`sshd`), вход по паролю для `root` (или `--user`), порт 22 открыт |

### Безопасность

- Пароль **не сохраняется** на диск
- Отдельный SSH-ключ: `/root/.ssh/socksctl_key`
- Конфиг: `/etc/socksctl/config.env` (без секретов)
- Предупреждение при прослушивании на `0.0.0.0`

### Лицензия

MIT — см. [LICENSE](LICENSE).

---

<div align="center">

[⬆ Back to top](#socksctl) · [English](#english) · [Русский](#русский)

</div>
