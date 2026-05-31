# Remnawave Node Installer

Автоматический скрипт для быстрой установки и настройки **Remnawave Node** с поддержкой мультиязычности (RU/EN), оптимизации сети и опциональным развертыванием маскировки **SelfSteal** (Caddy).

## Что умеет скрипт:
* Автоматическое обновление пакетов и установка Docker.
* Включение базового BBR (опционально BBR3).
* Отключение IPv6 (по желанию).
* Развертывание Remnawave Node с автоматической генерацией `docker-compose.yml`.
* Опциональная настройка маскировки SelfSteal (Caddy + HTML-заглушка).

---

## Быстрая установка (Установка одной командой)

Просто скопируй и вставь эту команду в терминал твоего сервера:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ImFraGushka/Remnawave-Node-installation-script/main/install.sh)

