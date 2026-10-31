# CrowdSec Custom Security

[🇷🇺 Русский](#-русская-версия) · [🇬🇧 English](#-english-version)

Custom CrowdSec configurations for Linux servers. The repository contains local parsers, scenarios, and acquisition configurations that complement the standard CrowdSec rules.

---

# 🇷🇺 Русская версия

## Назначение

Репозиторий предназначен для централизованного хранения, версионирования и развёртывания собственных конфигураций CrowdSec.

Сейчас доступны два независимых набора правил:

- **SSH** — защита от попыток входа под несуществующим пользователем и попыток SSH-аутентификации под `root`;
- **3x-ui** — обнаружение brute-force атак на веб-панель 3x-ui.

Наборы можно устанавливать по отдельности или вместе. Установка одного набора не удаляет и не изменяет файлы другого.

CrowdSec создаёт `decision`, а Firewall Bouncer применяет его на уровне firewall. Собственные правила работают совместно со стандартной конфигурацией CrowdSec и не заменяют её.

## Требования

- Linux-сервер;
- установленный и настроенный CrowdSec;
- для фактической блокировки IP — установленный и подключённый Firewall Bouncer;
- для набора `3x-ui` — 3x-ui с журналом `/var/log/x-ui/3xui.log`.

## Установка

Клонировать репозиторий и перейти в его каталог:

```bash
git clone https://github.com/Daywer/crowdsec-custom.git
cd crowdsec-custom
```

Установочный скрипт принимает один обязательный аргумент:

```text
sudo ./install.sh {ssh|3x-ui|all}
```

Примеры:

```bash
# Установить только SSH-правила
sudo ./install.sh ssh

# Установить только правила для 3x-ui
sudo ./install.sh 3x-ui

# Установить все доступные наборы
sudo ./install.sh all
```

Скрипт устанавливает только выбранный набор:

| Аргумент | Что устанавливается |
|---|---|
| `ssh` | SSH parser и два SSH-сценария |
| `3x-ui` | parser, сценарий и acquisition-файл для 3x-ui |
| `all` | оба набора |

После установки скрипт:

1. проверяет конфигурацию CrowdSec командой `crowdsec -c /etc/crowdsec/config.yaml -t`;
2. перезапускает CrowdSec только в случае успешной проверки.

Если проверка конфигурации завершается ошибкой, скрипт останавливается и не перезапускает CrowdSec.

> Повторный запуск установщика безопасен для уже установленных файлов: файлы выбранного набора перезаписываются актуальными версиями из репозитория. Файлы других наборов не удаляются.

## Структура репозитория

```text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   ├── sshd-session-local.yaml
│   └── 3x-ui-logs.yaml
├── scenarios/
│   ├── ssh-invalid-user-local.yaml
│   ├── ssh-root-auth-local.yaml
│   └── 3x-ui-bf.yaml
└── acquisition/
    └── 3x-ui.yaml
```

## Набор SSH

### Parser

Файл: `parsers/sshd-session-local.yaml`

Parser предназначен для OpenSSH, использующего процесс `sshd-session`.

Обрабатываются два типа сообщений.

**Несуществующий пользователь:**

```text
Connection closed by invalid user <user> <IP> port <port> [preauth]
```

Из сообщения извлекаются `source_ip` и `target_user`. Создаётся событие:

```text
log_type = ssh_failed-auth
```

**Попытка аутентификации под root:**

```text
Connection closed by authenticating user root <IP> port <port> [preauth]
```

Создаётся событие:

```text
log_type = ssh_root-auth
```

с параметрами `source_ip` и `target_user = root`.

### Сценарии

| Файл | Имя сценария | Условие |
|---|---|---|
| `scenarios/ssh-invalid-user-local.yaml` | `local/ssh-invalid-user` | одна попытка входа под несуществующим пользователем |
| `scenarios/ssh-root-auth-local.yaml` | `local/ssh-root-auth` | одна попытка SSH-аутентификации под `root` |

Каждое из этих событий является основанием для немедленного создания CrowdSec alert и блокировки IP. Срок блокировки определяется общей политикой CrowdSec в `/etc/crowdsec/profiles.yaml`. В текущей конфигурации используется срок 24 часа.

Стандартные сценарии CrowdSec продолжают работать независимо:

```text
crowdsecurity/ssh-bf
crowdsecurity/ssh-bf_user-enum
crowdsecurity/ssh-slow-bf
crowdsecurity/ssh-slow-bf_user-enum
```

## Набор 3x-ui

### Источник журналов (acquisition)

Файл в репозитории: `acquisition/3x-ui.yaml`

Установочный скрипт размещает его в:

```text
/etc/crowdsec/acquis.d/3x-ui.yaml
```

Конфигурация читает журнал:

```text
/var/log/x-ui/3xui.log
```

и передаёт записи CrowdSec с типом `3x-ui`.

### Parser

Файл: `parsers/3x-ui-logs.yaml`

Parser обрабатывает записи о неудачной авторизации в веб-панели 3x-ui. Пример записи:

```text
2026/10/31 13:43:35 WARNING - failed login: username="admin", IP="203.0.113.10", reason="invalid credentials"
```

Извлекаются:

- `username` — имя пользователя;
- `source_ip` — IP-адрес источника;
- `reason` — причина отказа.

Для события устанавливаются метаданные:

```text
log_type = 3x-ui_failed_login
service = 3x-ui
source_ip = <IP>
```

Успешные авторизации не являются событиями для этого сценария.

### Сценарий brute-force

Файл: `scenarios/3x-ui-bf.yaml`

Имя сценария:

```text
local/3x-ui-bf
```

Параметры обнаружения:

| Параметр | Значение |
|---|---|
| Группировка | IP-адрес источника (`source_ip`) |
| Порог | 3 неудачные попытки |
| Окно накопления | 5 минут |
| Время блокировки (`blackhole`) | 24 часа |

Таким образом, три неудачные попытки входа с одного IP в пределах пяти минут приводят к созданию решения CrowdSec. Firewall Bouncer применяет блокировку на уровне firewall.

## Проверка

### Проверить конфигурацию CrowdSec

```bash
sudo crowdsec -c /etc/crowdsec/config.yaml -t
```

### Посмотреть установленные сценарии

```bash
sudo cscli scenarios list
```

Для выборочной проверки:

```bash
sudo cscli scenarios list | grep -E 'ssh-invalid|ssh-root|3x-ui-bf'
```

### Проверить SSH parser

Для invalid user:

```bash
sudo cscli explain --log 'Sep 04 10:14:54 1cadman.egs54.ru sshd-session[2000214]: Connection closed by invalid user test 221.153.12.93 port 48956 [preauth]' --type syslog
```

Для root:

```bash
sudo cscli explain --log 'Sep 04 10:25:41 1cadman.egs54.ru sshd-session[2006083]: Connection closed by authenticating user root 75.64.135.45 port 49414 [preauth]' --type syslog
```

В обоих случаях проверьте успешное прохождение соответствующего локального parser.

### Проверить 3x-ui parser

```bash
sudo cscli explain \
  --log '2026/10/31 13:43:35 WARNING - failed login: username="admin", IP="203.0.113.10", reason="invalid credentials"' \
  --type 3x-ui \
  --verbose
```

В выводе должен присутствовать parser `local/3x-ui-logs`, извлечённые `username`, `reason`, `source_ip` и метаданные `log_type = 3x-ui_failed_login`.

### Проверить решения CrowdSec

```bash
sudo cscli decisions list
```

Для конкретного IP:

```bash
sudo cscli decisions list --ip 203.0.113.10
```

### Проверить Firewall Bouncer

```bash
sudo nft list ruleset
```

Фактическая блокировка на уровне firewall требует работающего Firewall Bouncer.

## Обновление

Получить изменения репозитория:

```bash
cd ~/crowdsec-custom
git pull
```

Затем переустановить нужный набор:

```bash
# Только SSH
sudo ./install.sh ssh

# Только 3x-ui
sudo ./install.sh 3x-ui

# Все наборы
sudo ./install.sh all
```

Установщик проверяет конфигурацию CrowdSec перед перезапуском службы.

## Версионирование

Рабочие версии конфигурации можно сохранять через Git tags.

Создание версии:

```bash
git tag -a v1.0.0 -m "Initial custom CrowdSec rules"
git push origin v1.0.0
```

Получение конкретной версии:

```bash
git fetch --tags
git checkout v1.0.0
```

Это позволяет вернуться к предыдущей версии правил.

## Важно

Собственные parser и scenario устанавливаются в:

```text
/etc/crowdsec/parsers/s01-parse/
/etc/crowdsec/scenarios/
```

Acquisition-файл 3x-ui устанавливается в:

```text
/etc/crowdsec/acquis.d/
```

Файлы официального CrowdSec Hub не изменяются. Собственные правила хранятся отдельно, чтобы обновления официального Hub не перезаписывали их.

## Развитие проекта

Репозиторий предназначен для постепенного накопления собственных конфигураций CrowdSec для разных сервисов.

Перед добавлением нового набора правил необходимо проверить:

- корректность конфигурации CrowdSec;
- обработку тестовых записей через `cscli explain`;
- работу на реальных логах;
- создание ожидаемого `alert`;
- создание ожидаемого `decision`;
- применение решения Firewall Bouncer.

---

# 🇬🇧 English Version

## Purpose

This repository provides centralized storage, version control, and deployment of custom CrowdSec configurations.

Two independent rule sets are currently available:

- **SSH** — protects against login attempts using nonexistent users and SSH authentication attempts as `root`;
- **3x-ui** — detects brute-force attacks against the 3x-ui web panel.

The rule sets can be installed separately or together. Installing one set does not remove or modify the files belonging to the other set.

CrowdSec creates a `decision`, and the Firewall Bouncer applies it at the firewall level. These custom rules complement the standard CrowdSec configuration; they do not replace it.

## Requirements

- A Linux server;
- CrowdSec installed and configured;
- A working Firewall Bouncer for actual IP blocking;
- For the `3x-ui` set, 3x-ui with its log file at `/var/log/x-ui/3xui.log`.

## Installation

Clone the repository and enter its directory:

```bash
git clone https://github.com/Daywer/crowdsec-custom.git
cd crowdsec-custom
```

The installer requires one argument:

```text
sudo ./install.sh {ssh|3x-ui|all}
```

Examples:

```bash
# Install SSH rules only
sudo ./install.sh ssh

# Install 3x-ui rules only
sudo ./install.sh 3x-ui

# Install all available rule sets
sudo ./install.sh all
```

| Argument | Installed components |
|---|---|
| `ssh` | SSH parser and two SSH scenarios |
| `3x-ui` | 3x-ui parser, scenario, and acquisition file |
| `all` | Both rule sets |

After installation, the script:

1. validates the CrowdSec configuration using `crowdsec -c /etc/crowdsec/config.yaml -t`;
2. restarts CrowdSec only if validation succeeds.

If validation fails, the script stops and does not restart CrowdSec.

Re-running the installer replaces the selected set's files with the versions from the repository. Files belonging to other sets are not removed.

## Repository Structure

```text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   ├── sshd-session-local.yaml
│   └── 3x-ui-logs.yaml
├── scenarios/
│   ├── ssh-invalid-user-local.yaml
│   ├── ssh-root-auth-local.yaml
│   └── 3x-ui-bf.yaml
└── acquisition/
    └── 3x-ui.yaml
```

## SSH Rule Set

### Parser

File: `parsers/sshd-session-local.yaml`

The parser is designed for OpenSSH using the `sshd-session` process.

It handles two message types.

**Nonexistent user:**

```text
Connection closed by invalid user <user> <IP> port <port> [preauth]
```

The parser extracts `source_ip` and `target_user` and creates the event:

```text
log_type = ssh_failed-auth
```

**Root authentication attempt:**

```text
Connection closed by authenticating user root <IP> port <port> [preauth]
```

The parser creates:

```text
log_type = ssh_root-auth
```

with `source_ip` and `target_user = root`.

### Scenarios

| File | Scenario name | Condition |
|---|---|---|
| `scenarios/ssh-invalid-user-local.yaml` | `local/ssh-invalid-user` | One login attempt using a nonexistent user |
| `scenarios/ssh-root-auth-local.yaml` | `local/ssh-root-auth` | One SSH authentication attempt as `root` |

Each event triggers a CrowdSec alert and an immediate IP ban. The ban duration is controlled by the global CrowdSec policy in `/etc/crowdsec/profiles.yaml`. The current configuration uses a 24-hour ban.

The standard CrowdSec scenarios continue to operate independently:

```text
crowdsecurity/ssh-bf
crowdsecurity/ssh-bf_user-enum
crowdsecurity/ssh-slow-bf
crowdsecurity/ssh-slow-bf_user-enum
```

## 3x-ui Rule Set

### Log Acquisition

Repository file: `acquisition/3x-ui.yaml`

The installer places it at:

```text
/etc/crowdsec/acquis.d/3x-ui.yaml
```

The configuration reads:

```text
/var/log/x-ui/3xui.log
```

and sends the log entries to CrowdSec with the `3x-ui` type.

### Parser

File: `parsers/3x-ui-logs.yaml`

The parser processes failed login records from the 3x-ui web panel. Example:

```text
2026/10/31 13:43:35 WARNING - failed login: username="admin", IP="203.0.113.10", reason="invalid credentials"
```

The parser extracts:

- `username` — the username;
- `source_ip` — the source IP address;
- `reason` — the failure reason.

The event receives the following metadata:

```text
log_type = 3x-ui_failed_login
service = 3x-ui
source_ip = <IP>
```

Successful logins are not events for this scenario.

### Brute-Force Scenario

File: `scenarios/3x-ui-bf.yaml`

Scenario name:

```text
local/3x-ui-bf
```

Detection parameters:

| Parameter | Value |
|---|---|
| Grouping | Source IP (`source_ip`) |
| Threshold | 3 failed attempts |
| Accumulation window | 5 minutes |
| Ban duration (`blackhole`) | 24 hours |

Three failed login attempts from the same IP within five minutes generate a CrowdSec decision. The Firewall Bouncer applies the block at the firewall level.

## Verification

### Validate CrowdSec Configuration

```bash
sudo crowdsec -c /etc/crowdsec/config.yaml -t
```

### List Installed Scenarios

```bash
sudo cscli scenarios list
```

To filter the custom scenarios:

```bash
sudo cscli scenarios list | grep -E 'ssh-invalid|ssh-root|3x-ui-bf'
```

### Test the SSH Parser

For an invalid user:

```bash
sudo cscli explain --log 'Sep 04 10:14:54 1cadman.egs54.ru sshd-session[2000214]: Connection closed by invalid user test 221.153.12.93 port 48956 [preauth]' --type syslog
```

For root:

```bash
sudo cscli explain --log 'Sep 04 10:25:41 1cadman.egs54.ru sshd-session[2006083]: Connection closed by authenticating user root 75.64.135.45 port 49414 [preauth]' --type syslog
```

In both cases, verify that the corresponding local parser succeeds.

### Test the 3x-ui Parser

```bash
sudo cscli explain \
  --log '2026/10/31 13:43:35 WARNING - failed login: username="admin", IP="203.0.113.10", reason="invalid credentials"' \
  --type 3x-ui \
  --verbose
```

The output should show the `local/3x-ui-logs` parser, the extracted `username`, `reason`, and `source_ip`, and the `log_type = 3x-ui_failed_login` metadata.

### Check CrowdSec Decisions

```bash
sudo cscli decisions list
```

For a specific IP:

```bash
sudo cscli decisions list --ip 203.0.113.10
```

### Check Firewall Bouncer

```bash
sudo nft list ruleset
```

Actual firewall blocking requires a running Firewall Bouncer.

## Updating

Pull the latest repository changes:

```bash
cd ~/crowdsec-custom
git pull
```

Then reinstall the required rule set:

```bash
# SSH only
sudo ./install.sh ssh

# 3x-ui only
sudo ./install.sh 3x-ui

# All rule sets
sudo ./install.sh all
```

The installer validates the CrowdSec configuration before restarting the service.

## Versioning

Working configurations can be saved using Git tags.

Create a version:

```bash
git tag -a v1.0.0 -m "Initial custom CrowdSec rules"
git push origin v1.0.0
```

Check out a specific version:

```bash
git fetch --tags
git checkout v1.0.0
```

This makes it possible to roll back to a previous set of rules.

## Important

Custom parsers and scenarios are installed into:

```text
/etc/crowdsec/parsers/s01-parse/
/etc/crowdsec/scenarios/
```

The 3x-ui acquisition file is installed into:

```text
/etc/crowdsec/acquis.d/
```

Official CrowdSec Hub files are not modified. Custom rules are stored separately so that official Hub updates do not overwrite them.

## Project Development

This repository is intended to become a growing collection of custom CrowdSec configurations for different services.

Before adding a new rule set, verify:

- CrowdSec configuration validity;
- correct parsing of test records with `cscli explain`;
- operation against real logs;
- generation of the expected `alert`;
- generation of the expected `decision`;
- enforcement of the decision by the Firewall Bouncer.
