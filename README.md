# RustDesk Server — установка одной командой

Скрипт поднимает собственный сервер [RustDesk](https://github.com/rustdesk/rustdesk-server) (hbbs + hbbr) через Docker. Подходит для Ubuntu / Debian.

## Установка

От root:

```bash
curl -fsSL https://raw.githubusercontent.com/sxcvio/Auto-Rustdesk-One-Command/main/install-rustdesk.sh | bash -s -- rd.example.com
```

Домен можно не указывать — тогда будет использован внешний IP сервера:

```bash
curl -fsSL https://raw.githubusercontent.com/sxcvio/Auto-Rustdesk-One-Command/main/install-rustdesk.sh | bash
```

В конце скрипт выведет данные для клиента: адрес сервера и ключ.

## Что делает скрипт

- ставит Docker, если его нет;
- создаёт `~/rustdesk/docker-compose.yml`;
- открывает порты в `ufw`, если он включён;
- запускает сервер и выводит публичный ключ.

## Порты

Открой в фаерволе хостера, если он есть:

- `21115-21117/tcp`
- `21116/udp`

## Настройка клиента

В RustDesk: **Настройки → Сеть → ID/Ретранслятор**

| Поле | Значение |
|---|---|
| Сервер ID | твой домен или IP |
| Ретранслятор | твой домен или IP |
| Сервер API | пусто |
| Key | ключ из вывода скрипта |

## Обновление

```bash
cd ~/rustdesk && docker compose pull && docker compose up -d
```

## Перенос на другой сервер

Скопируй ключи со старого сервера, чтобы не перенастраивать клиенты:

```bash
scp root@СТАРЫЙ_IP:~/rustdesk/data/id_ed25519* ~/rustdesk/data/
cd ~/rustdesk && docker compose restart
```

Файл `~/rustdesk/data/id_ed25519` — приватный ключ сервера. Никому его не передавай и не заливай в репозиторий.
