<div align="center">

# 🖥️ Auto RustDesk — One Command

**Свой сервер удалённого доступа, как AnyDesk, за одну команду**

[![RustDesk](https://img.shields.io/badge/RustDesk-Server-024EFF?style=for-the-badge&logo=rust&logoColor=white)](https://github.com/rustdesk/rustdesk-server)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-supported-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Debian](https://img.shields.io/badge/Debian-supported-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://www.debian.org/)

[Установка](#-установка) •
[Настройка клиента](#-настройка-клиента) •
[Обновление](#-обновление) •
[Перенос](#-перенос-на-другой-сервер) •
[FAQ](#-faq)

</div>

---

## ✨ Что это

Скрипт поднимает собственный сервер [RustDesk](https://github.com/rustdesk/rustdesk-server) (`hbbs` + `hbbr`) в Docker. Подключения идут через **твой** сервер, а не через чужие. Это бесплатно, без лимитов и без регистрации.

| | |
|---|---|
| ⚡ **Одна команда** | Docker, конфиг, порты и запуск настраиваются сами |
| 🔐 **Свой ключ шифрования** | Генерируется при установке, к серверу подключаются только твои клиенты |
| 🔄 **Автозапуск** | Сервер сам поднимается после перезагрузки |
| 🆓 **Полностью бесплатно** | Open-source сервер RustDesk, без подписок |

---

## 🚀 Установка

> Нужен сервер на **Ubuntu / Debian** и доступ под **root**.

**С доменом** (рекомендуется):

```bash
curl -fsSL https://raw.githubusercontent.com/sxcvio/Auto-Rustdesk-One-Command/main/install-rustdesk.sh | bash -s -- rd.example.com
```

**Без домена** (используется внешний IP сервера):

```bash
curl -fsSL https://raw.githubusercontent.com/sxcvio/Auto-Rustdesk-One-Command/main/install-rustdesk.sh | bash
```

В конце ты увидишь готовые данные для клиента:

```
================ RustDesk сервер готов ================
 Сервер ID:     rd.example.com
 Ретранслятор:  rd.example.com
 Сервер API:    (пусто)
 Key:           AbCdEf...=
========================================================
```

<details>
<summary><b>🔧 Что делает скрипт</b></summary>

<br>

1. Ставит Docker, если его нет
2. Создаёт `~/rustdesk/docker-compose.yml`
3. Открывает порты в `ufw`, если он включён
4. Скачивает образ и запускает `hbbs` и `hbbr`
5. Ждёт генерации ключа и выводит данные для подключения

</details>

---

## 🌐 Порты

Если у хостера есть свой фаервол в панели, открой там:

| Порт | Протокол | Назначение |
|---|---|---|
| `21115` | TCP | Проверка типа NAT |
| `21116` | TCP + UDP | ID-сервер, пробивка NAT |
| `21117` | TCP | Ретранслятор (relay) |

---

## 💻 Настройка клиента

Скачай клиент: [**Windows / macOS / Linux / Android**](https://github.com/rustdesk/rustdesk/releases/latest) · [**iPhone / iPad**](https://apps.apple.com/app/id1581225015)

Открой **Настройки → Сеть → ID/Ретранслятор** и заполни:

| Поле | Значение |
|---|---|
| **Сервер ID** | твой домен или IP |
| **Ретранслятор** | твой домен или IP |
| **Сервер API** | *оставь пустым* |
| **Key** | ключ из вывода скрипта |

> 💡 **Совет:** настрой один клиент, нажми иконку «копировать» в окне ID/Ретранслятор и вставь строку на других устройствах кнопкой «вставить».

Если внизу клиента горит **🟢 Готово**, всё работает.

---

## 🔄 Обновление

```bash
cd ~/rustdesk && docker compose pull && docker compose up -d
```

---

## 📦 Перенос на другой сервер

Чтобы не перенастраивать клиенты, перенеси ключи:

```bash
# на новом сервере, после установки
scp root@СТАРЫЙ_IP:~/rustdesk/data/id_ed25519* ~/rustdesk/data/
cd ~/rustdesk && docker compose restart
```

Затем направь домен на новый IP. Клиенты подключатся сами.

> ⚠️ `~/rustdesk/data/id_ed25519` — **приватный ключ** сервера. Никому его не передавай и не заливай в репозиторий.

---

## ❓ FAQ

<details>
<summary><b>Это платно?</b></summary>

<br>

Нет. Open-source сервер RustDesk бесплатный и без ограничений. Платная только отдельная версия **Server Pro** (веб-панель, логины, адресная книга), для обычных подключений она не нужна.

</details>

<details>
<summary><b>Клиент пишет «Не готово»</b></summary>

<br>

Почти всегда закрыты порты. Проверь фаервол в панели хостера и `ufw status`. Проверить порт с другого компьютера:

```bash
nc -zv rd.example.com 21116
```

</details>

<details>
<summary><b>Что писать в «Сервер API»?</b></summary>

<br>

Ничего. Это поле нужно только для Server Pro. Предупреждение про HTTP можно игнорировать: трафик рабочего стола шифруется ключом.

</details>

<details>
<summary><b>Можно ли управлять айфоном?</b></summary>

<br>

Нет. iOS не позволяет сторонним приложениям управлять устройством. С айфона можно только подключаться к другим устройствам.

</details>

<details>
<summary><b>Домен на Cloudflare</b></summary>

<br>

Выключи проксирование для записи (серое облако, **DNS only**). Порты RustDesk через прокси Cloudflare не работают.

</details>

<details>
<summary><b>Как посмотреть логи / остановить сервер?</b></summary>

<br>

```bash
cd ~/rustdesk
docker compose logs -f     # логи
docker compose down        # остановить
docker compose up -d       # запустить
```

</details>

---

<div align="center">

Сделано на основе [rustdesk/rustdesk-server](https://github.com/rustdesk/rustdesk-server)

⭐ Если пригодилось, поставь звезду

</div>
