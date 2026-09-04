# CrowdSec Custom Security

Custom CrowdSec configurations for Linux servers.

---

# 🇷🇺 Русская версия

## Назначение

Этот репозиторий предназначен для централизованного хранения, версионирования и развёртывания собственных правил CrowdSec.

Основная задача текущей конфигурации — усилить защиту SSH от автоматических атак.

Текущие правила:

- попытка SSH-входа под несуществующим пользователем — немедленный бан IP;
- попытка SSH-аутентификации под `root` — немедленный бан IP;
- стандартные сценарии CrowdSec `ssh-bf`, `ssh-bf_user-enum`, `ssh-slow-bf` и `ssh-slow-bf_user-enum` продолжают работать независимо от собственных правил.

CrowdSec создаёт `decision`, а Firewall Bouncer применяет его на уровне firewall.

> **Примечание:** собственные правила работают совместно со стандартной конфигурацией CrowdSec, а не заменяют её.

## Структура репозитория

```text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   └── sshd-session-local.yaml
└── scenarios/
    ├── ssh-invalid-user-local.yaml
    └── ssh-root-auth-local.yaml
```

## Parser

Файл:

```text
parsers/sshd-session-local.yaml
```

Parser предназначен для OpenSSH, использующего процесс `sshd-session`.

Он обрабатывает два типа событий.

### Несуществующий пользователь

```text
Connection closed by invalid user <user> <IP> port <port> [preauth]
```

Из события извлекаются:

```text
source_ip
target_user
```

Создаётся событие CrowdSec:

```text
log_type = ssh_failed-auth
```

### Попытка аутентификации под root

```text
Connection closed by authenticating user root <IP> port <port> [preauth]
```

Создаётся событие:

```text
log_type = ssh_root-auth
```

с параметрами:

```text
source_ip
target_user = root
```

## Scenario: несуществующий пользователь

Файл:

```text
scenarios/ssh-invalid-user-local.yaml
```

Имя сценария:

```text
local/ssh-invalid-user
```

Логика:

```text
invalid user
      ↓
1 событие
      ↓
CrowdSec alert
      ↓
BAN
```

Одна попытка входа под несуществующим пользователем является основанием для немедленной блокировки IP.

## Scenario: root

Файл:

```text
scenarios/ssh-root-auth-local.yaml
```

Имя сценария:

```text
local/ssh-root-auth
```

Логика:

```text
попытка SSH-аутентификации под root
      ↓
1 событие
      ↓
CrowdSec alert
      ↓
BAN
```

Правило применяется только к `root`.

## Срок блокировки

Продолжительность бана задаётся общей политикой CrowdSec в:

```text
/etc/crowdsec/profiles.yaml
```

В текущей инфраструктуре используется срок:

```text
24 часа
```

Поэтому новые решения, создаваемые этими сценариями, получают бан на 24 часа.

## Стандартные SSH-сценарии CrowdSec

Собственные правила не заменяют штатные сценарии CrowdSec.

Продолжают работать:

```text
crowdsecurity/ssh-bf
crowdsecurity/ssh-bf_user-enum
crowdsecurity/ssh-slow-bf
crowdsecurity/ssh-slow-bf_user-enum
```

Итоговая схема:

```text
SSH
├── invalid user
│   └── 1 событие → BAN
│
├── root authentication attempt
│   └── 1 событие → BAN
│
├── обычный bruteforce
│   └── crowdsecurity/ssh-bf
│
└── медленный bruteforce
    └── crowdsecurity/ssh-slow-bf
```

## Установка

На целевом сервере должен быть установлен CrowdSec.

```bash
git clone git@github.com:Daywer/crowdsec-custom.git
cd crowdsec-custom
sudo ./install.sh
```

Скрипт автоматически:

1. устанавливает parser;
2. устанавливает сценарии;
3. проверяет конфигурацию CrowdSec;
4. перезапускает CrowdSec только после успешной проверки.

Перед перезапуском выполняется:

```bash
crowdsec -c /etc/crowdsec/config.yaml -t
```

Если проверка не проходит, CrowdSec не перезапускается.

## Проверка

### Проверить установленные сценарии

```bash
sudo cscli scenarios list | grep -E 'ssh-invalid|ssh-root|ssh-bf'
```

### Проверить parser для invalid user

```bash
sudo cscli explain --log 'Sep 04 10:14:54 1cadman.egs54.ru sshd-session[2000214]: Connection closed by invalid user test 221.153.12.93 port 48956 [preauth]' --type syslog
```

Ожидаемый результат:

```text
parser success
```

### Проверить parser для root

```bash
sudo cscli explain --log 'Sep 04 10:25:41 1cadman.egs54.ru sshd-session[2006083]: Connection closed by authenticating user root 75.64.135.45 port 49414 [preauth]' --type syslog
```

Ожидаемый результат:

```text
parser success
```

### Проверить активные решения

```bash
sudo cscli decisions list
```

### Проверить конкретный IP

```bash
sudo cscli decisions list --ip 1.2.3.4
```

### Проверить Firewall Bouncer

```bash
sudo nft list ruleset
```

## Обновление

После изменения правил:

```bash
cd ~/crowdsec-custom
git pull
sudo ./install.sh
```

Перед перезапуском конфигурация снова проверяется.

## Версионирование

Рабочие версии конфигурации сохраняются через Git tags.

Создание версии:

```bash
git tag -a v1.0.0 -m "Initial working SSH protection"
git push origin v1.0.0
```

Получение конкретной версии:

```bash
git fetch --tags
git checkout v1.0.0
```

Это позволяет откатиться к предыдущей рабочей версии.

## Важно

Собственные parser и scenario устанавливаются в:

```text
/etc/crowdsec/parsers/s01-parse/
/etc/crowdsec/scenarios/
```

Файлы официального CrowdSec Hub не изменяются.

Собственные правила хранятся отдельно, чтобы обновления официального Hub не перезаписывали их.

## Развитие проекта

Репозиторий предназначен для постепенного накопления собственных решений CrowdSec.

Перед добавлением нового правила оно должно:

- пройти проверку конфигурации CrowdSec;
- корректно обрабатываться через `cscli explain`;
- быть проверено на реальных логах;
- быть проверено на реальном `alert`;
- быть проверено на реальном `decision`.

В дальнейшем сюда можно добавлять собственные правила для SSH, Apache, Nginx, PostgreSQL, Docker и других Linux-сервисов.

---

# 🇬🇧 English Version

## Purpose

This repository is intended for centralized storage, version control, and deployment of custom CrowdSec rules.

The main goal of the current configuration is to strengthen SSH protection against automated attacks.

Current rules:

- an SSH login attempt using a nonexistent user results in an immediate IP ban;
- an SSH authentication attempt as `root` results in an immediate IP ban;
- the standard CrowdSec scenarios `ssh-bf`, `ssh-bf_user-enum`, `ssh-slow-bf`, and `ssh-slow-bf_user-enum` continue to operate independently of the custom rules.

CrowdSec creates the `decision`, while the Firewall Bouncer applies it at firewall level.

> **Note:** these custom rules work alongside the standard CrowdSec configuration and do not replace it.

## Repository Structure

```text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   └── sshd-session-local.yaml
└── scenarios/
    ├── ssh-invalid-user-local.yaml
    └── ssh-root-auth-local.yaml
```

## Parser

File:

```text
parsers/sshd-session-local.yaml
```

The parser is designed for OpenSSH using the `sshd-session` process.

It handles two types of events.

### Nonexistent User

```text
Connection closed by invalid user <user> <IP> port <port> [preauth]
```

The parser extracts:

```text
source_ip
target_user
```

and creates the CrowdSec event:

```text
log_type = ssh_failed-auth
```

### Root Authentication Attempt

```text
Connection closed by authenticating user root <IP> port <port> [preauth]
```

The parser creates:

```text
log_type = ssh_root-auth
```

with:

```text
source_ip
target_user = root
```

## Scenario: Nonexistent User

File:

```text
scenarios/ssh-invalid-user-local.yaml
```

Scenario name:

```text
local/ssh-invalid-user
```

Logic:

```text
invalid user
      ↓
1 event
      ↓
CrowdSec alert
      ↓
BAN
```

A single SSH login attempt using a nonexistent user is enough to trigger an immediate IP ban.

## Scenario: Root Authentication

File:

```text
scenarios/ssh-root-auth-local.yaml
```

Scenario name:

```text
local/ssh-root-auth
```

Logic:

```text
SSH authentication attempt as root
      ↓
1 event
      ↓
CrowdSec alert
      ↓
BAN
```

The rule applies specifically to `root`.

## Ban Duration

The ban duration is controlled by the global CrowdSec policy in:

```text
/etc/crowdsec/profiles.yaml
```

The current infrastructure uses:

```text
24 hours
```

Therefore, new decisions generated by these scenarios receive a 24-hour ban.

## Standard CrowdSec SSH Scenarios

The custom rules do not replace the standard CrowdSec scenarios.

The following continue to operate:

```text
crowdsecurity/ssh-bf
crowdsecurity/ssh-bf_user-enum
crowdsecurity/ssh-slow-bf
crowdsecurity/ssh-slow-bf_user-enum
```

Overall protection:

```text
SSH
├── invalid user
│   └── 1 event → BAN
│
├── root authentication attempt
│   └── 1 event → BAN
│
├── normal bruteforce
│   └── crowdsecurity/ssh-bf
│
└── slow bruteforce
    └── crowdsecurity/ssh-slow-bf
```

## Installation

CrowdSec must already be installed on the target server.

```bash
git clone git@github.com:Daywer/crowdsec-custom.git
cd crowdsec-custom
sudo ./install.sh
```

The installer automatically:

1. installs the parser;
2. installs the scenarios;
3. validates the CrowdSec configuration;
4. restarts CrowdSec only after successful validation.

Before restarting, the following validation is performed:

```bash
crowdsec -c /etc/crowdsec/config.yaml -t
```

If validation fails, CrowdSec is not restarted.

## Verification

### Check installed scenarios

```bash
sudo cscli scenarios list | grep -E 'ssh-invalid|ssh-root|ssh-bf'
```

### Test the parser for invalid user

```bash
sudo cscli explain --log 'Sep 04 10:14:54 1cadman.egs54.ru sshd-session[2000214]: Connection closed by invalid user test 221.153.12.93 port 48956 [preauth]' --type syslog
```

Expected result:

```text
parser success
```

### Test the parser for root

```bash
sudo cscli explain --log 'Sep 04 10:25:41 1cadman.egs54.ru sshd-session[2006083]: Connection closed by authenticating user root 75.64.135.45 port 49414 [preauth]' --type syslog
```

Expected result:

```text
parser success
```

### Check active decisions

```bash
sudo cscli decisions list
```

### Check a specific IP

```bash
sudo cscli decisions list --ip 1.2.3.4
```

### Check Firewall Bouncer

```bash
sudo nft list ruleset
```

## Updating

After changing the rules:

```bash
cd ~/crowdsec-custom
git pull
sudo ./install.sh
```

The configuration is validated again before CrowdSec is restarted.

## Versioning

Working configurations are versioned using Git tags.

Create a version:

```bash
git tag -a v1.0.0 -m "Initial working SSH protection"
git push origin v1.0.0
```

Get a specific version:

```bash
git fetch --tags
git checkout v1.0.0
```

This allows you to roll back to a previous working version.

## Important

Custom parsers and scenarios are installed into:

```text
/etc/crowdsec/parsers/s01-parse/
/etc/crowdsec/scenarios/
```

Official CrowdSec Hub files are not modified.

Custom rules are stored separately so that updates to the official Hub do not overwrite them.

## Project Development

This repository is intended to become a growing collection of custom CrowdSec security solutions.

Before adding a new rule, it should:

- pass CrowdSec configuration validation;
- work correctly with `cscli explain`;
- be tested against real logs;
- be verified through a real `alert`;
- be verified through a real `decision`.

Additional custom rules for SSH, Apache, Nginx, PostgreSQL, Docker, and other Linux services can be added in the future.
