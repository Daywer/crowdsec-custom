CrowdSec Custom Security
<div align="center"> <img src="https://img.shields.io/badge/CrowdSec-v1.6+-blue.svg" alt="CrowdSec"> <img src="https://img.shields.io/badge/Linux-Supported-green.svg" alt="Linux"> <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License"> </div>
Набор собственных конфигураций CrowdSec для Linux-серверов.

Этот репозиторий содержит локальные parser'ы и scenario, которые дополняют стандартные правила CrowdSec.

📖 Русская версия
🎯 Назначение
Репозиторий предназначен для централизованного хранения и развёртывания собственных правил CrowdSec.

Основная задача текущей конфигурации — усилить защиту SSH от автоматических атак.

В частности:

🔒 попытка SSH-входа под несуществующим пользователем блокирует IP сразу;

🔒 попытка SSH-аутентификации под root блокирует IP сразу;

🔄 стандартные CrowdSec-сценарии ssh-bf и ssh-slow-bf продолжают работать независимо от наших правил.

Баны создаются CrowdSec, а Firewall Bouncer применяет их на уровне firewall.

📂 Структура
text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   └── sshd-session-local.yaml
└── scenarios/
    ├── ssh-invalid-user-local.yaml
    └── ssh-root-auth-local.yaml
🛠 Установка
bash
git clone https://github.com/yourusername/crowdsec-custom.git
cd crowdsec-custom
sudo ./install.sh
🇬🇧 English Version
🎯 Purpose
This repository is designed for centralized storage and deployment of custom CrowdSec rules.

The main goal of the current configuration is to strengthen SSH protection against automated attacks.

Specifically:

🔒 An attempt to SSH login with a non-existent user immediately blocks the IP;

🔒 An attempt to SSH authenticate as root immediately blocks the IP;

🔄 The standard CrowdSec scenarios ssh-bf and ssh-slow-bf continue to operate independently of our rules.

Bans are created by CrowdSec, and the Firewall Bouncer applies them at the firewall level.

📂 Structure
text
crowdsec-custom/
├── README.md
├── install.sh
├── parsers/
│   └── sshd-session-local.yaml
└── scenarios/
    ├── ssh-invalid-user-local.yaml
    └── ssh-root-auth-local.yaml
🛠 Installation
bash
git clone https://github.com/yourusername/crowdsec-custom.git
cd crowdsec-custom
sudo ./install.sh
📝 License / Лицензия
MIT © 2026

⚡ Note: These rules work alongside standard CrowdSec configurations, not replacing them.

Примечание: Эти правила работают вместе со стандартными конфигурациями CrowdSec, не заменяя их.


