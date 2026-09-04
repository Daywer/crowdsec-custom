# CrowdSec Custom Security

Набор собственных конфигураций CrowdSec для Linux-серверов.

Этот репозиторий содержит локальные parser'ы и scenario, которые дополняют стандартные правила CrowdSec.

---

# Русская версия

## Назначение

Репозиторий предназначен для централизованного хранения и развёртывания собственных правил CrowdSec.

Основная задача текущей конфигурации — усилить защиту SSH от автоматических атак.

В частности:

- попытка SSH-входа под несуществующим пользователем блокирует IP сразу;
- попытка SSH-аутентификации под `root` блокирует IP сразу;
- стандартные CrowdSec-сценарии `ssh-bf` и `ssh-slow-bf` продолжают работать независимо от наших правил.

Баны создаются CrowdSec, а Firewall Bouncer применяет их на уровне firewall.

## Структура

```text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   └── sshd-session-local.yaml
└── scenarios/
    ├── ssh-invalid-user-local.yaml
    └── ssh-root-auth-local.yaml

---

# English Version
## Purpose

This repository is intended for centralized storage and deployment of custom CrowdSec rules.

The repository contains local parsers and scenarios that complement the standard CrowdSec rules.

The main goal of the current configuration is to strengthen SSH protection against automated attacks.

Specifically:

an SSH login attempt using a nonexistent user immediately results in an IP ban;
an SSH authentication attempt as root immediately results in an IP ban;
the standard CrowdSec scenarios ssh-bf and ssh-slow-bf continue to operate independently of the custom rules.

Bans are created by CrowdSec, while the Firewall Bouncer applies them at the firewall level.

Structure
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   └── sshd-session-local.yaml
└── scenarios/
    ├── ssh-invalid-user-local.yaml
    └── ssh-root-auth-local.yaml
