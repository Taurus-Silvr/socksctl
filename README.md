# socksctl

Persistent SSH SOCKS5 tunnel in one command.  
Разблокировка доступа к API (Telegram и др.) через зарубежный VPS.

## Быстрая установка

### Одна команда (рекомендуется — только github.com, без raw)

```bash
bash -c 'd=$(mktemp -d); curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz | tar xz -C "$d" --strip-components=1; exec bash "$d/install.sh"'
```

Root — без sudo. Одно скачивание архива (~13 KB), дальше мастер установки.

### Если сеть нестабильная (скачать в файл, потом распаковать)

```bash
curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 -o /tmp/socksctl.tgz https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz && mkdir -p /tmp/socksctl-src && tar xzf /tmp/socksctl.tgz -C /tmp/socksctl-src --strip-components=1 && bash /tmp/socksctl-src/install.sh
```

### Через get.sh (может не работать, если raw.githubusercontent.com заблокирован)

```bash
curl -fsSL https://raw.githubusercontent.com/Taurus-Silvr/socksctl/main/get.sh | sh
```

> **Почему «зависает» `curl ... | sh`?**  
> Первая загрузка идёт с `raw.githubusercontent.com`. В РФ он часто таймаутит по SSL — скрипт не доходит до `sh`, вывода нет.  
> **Не используйте:** `curl ... | sudo bash` — sudo ломает pipe.

С sudo (не root):

```bash
sudo bash -c 'd=$(mktemp -d); curl -fsSL --connect-timeout 30 --max-time 300 --retry 5 https://github.com/Taurus-Silvr/socksctl/archive/refs/heads/main.tar.gz | tar xz -C "$d" --strip-components=1; exec bash "$d/install.sh"'
```

Введите **IP внешнего VPS** и **пароль root** (один раз).  
На выходе: `socks5h://127.0.0.1:1080`

### Альтернатива — git clone

```bash
git clone https://github.com/Taurus-Silvr/socksctl.git
cd socksctl
sudo bash install.sh
```

## Проверка

```bash
# IP через прокси = IP вашего VPS
curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me

# Telegram API (в РФ без прокси обычно не открывается)
curl --socks5-hostname 127.0.0.1:1080 https://api.telegram.org

sudo socksctl status
sudo socksctl docto
```

## Команды

| Команда | Описание |
|---------|----------|
| `sudo socksctl install` | Интерактивная установка / переустановка |
| `sudo socksctl status` | Статус сервиса и адрес SOCKS5 |
| `sudo socksctl restart` | Перезапуск туннеля |
| `sudo socksctl logs` | Логи (`journalctl -f`) |
| `sudo socksctl doctor` | Диагностика |
| `sudo socksctl uninstall` | Удаление |

## Неинтерактивный режим

```bash
sudo socksctl install \
  --host 1.2.3.4 \
  --user root \
  --listen-host 127.0.0.1 \
  --listen-port 1080 \
  --yes
```

## Расширенная настройка

```bash
sudo socksctl install --advanced
```

SSH-порт, пользователь, адрес прослушивания (127.0.0.1 / 0.0.0.0 / custom).

## Как это работает

```text
Приложение → 127.0.0.1:1080 (SOCKS5) → SSH-туннель → VPS → интернет
```

- Новый сетевой интерфейс **не создаётся** — только локальный порт
- SSH-ключ: `/root/.ssh/socksctl_key`
- systemd-сервис: `socksctl-tunnel` (автозапуск после reboot)
- Конфиг: `/etc/socksctl/config.env` (без паролей)

## Требования

**Локальный сервер:** Ubuntu 20.04/22.04/24.04 или Debian 11+, root/sudo

**Внешний VPS:** sshd, вход по паролю для root (или `--user`), открытый SSH-порт

## Примеры для приложений

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

## SSH на VPS без пароля (ключ socksctl)

```bash
ssh -i /root/.ssh/socksctl_key root@YOUR_VPS_IP
```

## Безопасность

- Пароль не сохраняется
- Отдельный SSH-ключ только для туннеля
- Предупреждение при прослушивании на `0.0.0.0`

## License

MIT — см. [LICENSE](LICENSE).
