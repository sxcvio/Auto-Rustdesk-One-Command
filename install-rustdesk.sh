#!/usr/bin/env bash
# ============================================================
#  Auto RustDesk — менеджер self-hosted RustDesk сервера
#  https://github.com/sxcvio/Auto-Rustdesk-One-Command
#
#  Запуск (меню):
#    curl -fsSL https://raw.githubusercontent.com/sxcvio/Auto-Rustdesk-One-Command/main/install-rustdesk.sh | bash
#
#  Установка без вопросов:
#    ... | bash -s -- install rd.example.com
#    ... | bash -s -- install            (с IP сервера)
# ============================================================
export LC_ALL=C.UTF-8 2>/dev/null || true

VERSION="2.0"
DIR="$HOME/rustdesk"
DATA="$DIR/data"
CONF="$DIR/.autorustdesk"
LOG="/tmp/rustdesk-install.log"
REPO="https://github.com/sxcvio/Auto-Rustdesk-One-Command"

# ================= оформление =================
if [ -t 1 ]; then
  R=$'\e[0m'; B=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; BLU=$'\e[34m'; MAG=$'\e[35m'; CYN=$'\e[36m'
  CLR=$'\r\e[K'
else
  R=""; B=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; MAG=""; CYN=""; CLR=$'\r'
fi

ok()   { printf "  ${GRN}✔${R} %s\n" "$1"; }
warn() { printf "  ${YLW}!${R} %s\n" "$1"; }
err()  { printf "  ${RED}✘${R} %s\n" "$1"; }
info() { printf "  ${CYN}›${R} %s\n" "$1"; }
hint() { printf "  ${DIM}%s${R}\n" "$1"; }

repeat() { local i; for ((i=0; i<$2; i++)); do printf '%s' "$1"; done; }
pad()    { local n=${#1}; printf '%s%*s' "$1" $(( $2 > n ? $2 - n : 0 )) ''; }

# Ввод с клавиатуры работает даже при запуске через curl | bash
if [ -r /dev/tty ] && { exec 3</dev/tty; } 2>/dev/null; then TTY=1; else TTY=0; fi

ask() { # ask "вопрос" переменная [по умолчанию]
  # внутренние имена с __, чтобы не перекрыть переменную вызывающей функции
  local __q="$1" __v="$2" __def="${3:-}" __ans=""
  if [ "$TTY" -eq 1 ]; then
    printf "  ${BLU}?${R} ${B}%s${R} " "$__q" >/dev/tty
    read -r -u 3 __ans || __ans=""
  fi
  [ -z "$__ans" ] && __ans="$__def"
  printf -v "$__v" '%s' "$__ans"
}

yes_no() { # yes_no "вопрос" y|n  → 0 = да
  local def="$2" a hintyn
  [ "$def" = y ] && hintyn="[Y/n]" || hintyn="[y/N]"
  while :; do
    ask "$1 $hintyn" a "$def"
    a="${a// /}"
    case "$a" in
      # «н» — это клавиша Y на русской раскладке, «т» — клавиша N
      y|Y|yes|Yes|YES|д|Д|да|Да|ДА|н|Н) return 0 ;;
      n|N|no|No|NO|т|Т|нет|Нет|НЕТ)     return 1 ;;
      *) printf "  ${DIM}Ответь y (да) или n (нет)${R}\n" ;;
    esac
  done
}

pause() { [ "$TTY" -eq 1 ] && { echo; ask "Enter — вернуться в меню" _ ""; }; }

# Шаг с анимацией: step "Текст" команда...
step() {
  local msg="$1"; shift
  echo "=== $msg" >>"$LOG"
  "$@" </dev/null >>"$LOG" 2>&1 &
  local pid=$! i=0 f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  if [ -t 1 ]; then
    while kill -0 "$pid" 2>/dev/null; do
      printf "${CLR}  ${CYN}%s${R} %s" "${f:i++%${#f}:1}" "$msg"; sleep 0.1
    done
  fi
  if wait "$pid"; then printf "$CLR"; ok "$msg"; return 0; fi
  printf "$CLR"; err "$msg"
  echo; hint "Последние строки лога ($LOG):"
  tail -n 15 "$LOG" | sed 's/^/    /'
  return 1
}

die() { err "$1"; [ -n "${2:-}" ] && info "$2"; pause; return 1; }

banner() {
  [ -t 1 ] && clear 2>/dev/null
  printf "${CYN}${B}"
  cat <<'EOF'

   ╦═╗╦ ╦╔═╗╔╦╗╔╦╗╔═╗╔═╗╦╔═
   ╠╦╝║ ║╚═╗ ║  ║║║╣ ╚═╗╠╩╗
   ╩╚═╚═╝╚═╝ ╩ ═╩╝╚═╝╚═╝╩ ╩
EOF
  printf "${R}   ${DIM}Auto RustDesk v%s · свой сервер удалённого доступа${R}\n" "$VERSION"
  printf "   ${DIM}Автор скрипта: ${R}sxcvio${DIM} · github.com/sxcvio${R}\n\n"
}

section() { printf "\n  ${B}%s${R}\n  ${DIM}%s${R}\n" "$1" "$(repeat '─' ${#1})"; }

# ================= утилиты =================
get_ip() {
  [ -n "${SERVER_IP:-}" ] && { echo "$SERVER_IP"; return; }
  local ip
  ip=$(curl -s -4 --max-time 5 https://api.ipify.org 2>/dev/null)
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ip=$(curl -s -4 --max-time 5 ifconfig.me 2>/dev/null)
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo "$ip"
}
resolve()      { getent ahostsv4 "$1" 2>/dev/null | awk 'NR==1{print $1}'; }
is_ip()        { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
is_domain()    { [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]; }
has_docker()   { command -v docker >/dev/null 2>&1; }
is_installed() { [ -f "$DIR/docker-compose.yml" ]; }
is_running()   { has_docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx hbbs \
                             && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx hbbr; }
has_key()      { [ -s "$DATA/id_ed25519" ] && [ -s "$DATA/id_ed25519.pub" ]; }
get_key()      { tr -d '\n\r ' <"$DATA/id_ed25519.pub"; }
saved_host()   { [ -f "$CONF" ] && sed -n 's/^HOST=//p' "$CONF" | head -n1; }
host_label()   { local h; h="$(saved_host)"; echo "${h:-адрес не сохранён}"; }
dc()           { (cd "$DIR" && docker compose "$@"); }

# Скрипт поиска ключей RustDesk — запускается локально или на удалённом сервере.
# Печатает папку с ключами. ~/.ssh никогда не трогается.
FIND_KEYS='
for c in hbbs rustdesk-hbbs hbbs-1; do
  m=$(docker inspect -f "{{range .Mounts}}{{if eq .Destination \"/root\"}}{{.Source}}{{end}}{{end}}" "$c" 2>/dev/null)
  [ -n "$m" ] && [ -s "$m/id_ed25519.pub" ] && [ -s "$m/id_ed25519" ] && { echo "$m"; exit 0; }
done
for d in "$HOME/rustdesk/data" /root/rustdesk/data /opt/rustdesk/data /opt/rustdesk \
         /var/lib/rustdesk-server /opt/rustdesk-server /opt/rustdesk-server/data /data/rustdesk; do
  [ -s "$d/id_ed25519.pub" ] && [ -s "$d/id_ed25519" ] && { echo "$d"; exit 0; }
done
f=$(find / -xdev -maxdepth 6 -name id_ed25519.pub -path "*rustdesk*" -not -path "*/.ssh/*" 2>/dev/null | head -n1)
[ -n "$f" ] && [ -s "$(dirname "$f")/id_ed25519" ] && { dirname "$f"; exit 0; }
exit 1
'

# ================= адрес сервера =================
choose_host() { # choose_host install|migrate
  local mode="$1" prev dns q
  HOST=""
  prev="$(saved_host)"

  section "Адрес сервера"
  info "IP этого сервера: ${B}${SERVER_IP:-не удалось определить}${R}"
  echo
  if [ "$mode" = migrate ]; then
    hint "Введи ${B}тот же домен${R}${DIM}, что был у старого сервера — тогда клиенты"
    hint "перенастраивать не придётся. Нет домена — нажми Enter (будет IP)."
  else
    hint "Если есть домен, направленный на этот сервер, введи его."
    hint "Нет домена — просто нажми Enter, будет использован IP."
  fi
  echo

  if [ -n "$prev" ] && [ "$prev" != "$SERVER_IP" ]; then
    q="Домен (Enter — оставить $prev):"
  else
    q="Домен (Enter — без домена):"; prev=""
  fi

  while :; do
    ask "$q" HOST "$prev"
    HOST="${HOST// /}"; HOST="${HOST#http://}"; HOST="${HOST#https://}"; HOST="${HOST%%/*}"; HOST="${HOST%%:*}"
    [ -z "$HOST" ] && break
    is_ip "$HOST" && break
    is_domain "$HOST" && break
    err "Похоже, это не домен. Пример: rd.example.com"
  done

  if [ -n "$HOST" ] && ! is_ip "$HOST"; then
    dns="$(resolve "$HOST")"
    if [ -n "$dns" ] && [ "$dns" = "$SERVER_IP" ]; then
      ok "Домен ${B}$HOST${R} указывает на этот сервер"
    elif [ "$mode" = migrate ] && [ -n "$dns" ]; then
      info "Домен пока указывает на ${B}$dns${R} (старый сервер) — это нормально."
      hint "  После переноса поменяешь A-запись на ${SERVER_IP}."
    else
      if [ -z "$dns" ]; then warn "Домен ${B}$HOST${R} не находится в DNS"
      else warn "Домен указывает на ${B}$dns${R}, а IP сервера — ${B}$SERVER_IP${R}"
           hint "  Если домен на Cloudflare — выключи прокси (DNS only)."; fi
      yes_no "Всё равно использовать этот домен?" y || HOST=""
    fi
  fi

  if [ -z "$HOST" ]; then
    HOST="$SERVER_IP"
    [ -z "$HOST" ] && { err "Не удалось определить IP сервера"; return 1; }
    ok "Будет использован IP: ${B}$HOST${R}"
  fi
}

# ================= ядро установки =================
write_compose() {
  mkdir -p "$DATA"
  cat >"$DIR/docker-compose.yml" <<'EOF'
services:
  hbbs:
    container_name: hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs
    volumes:
      - ./data:/root
    network_mode: host
    depends_on:
      - hbbr
    restart: unless-stopped

  hbbr:
    container_name: hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr
    volumes:
      - ./data:/root
    network_mode: host
    restart: unless-stopped
EOF
}

ensure_docker() {
  if has_docker; then ok "Docker уже установлен"
  else step "Устанавливаю Docker (1–2 минуты)" sh -c 'curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sh /tmp/get-docker.sh' || return 1; fi
  step "Запускаю службу Docker" sh -c 'systemctl enable --now docker || service docker start || true'
  if ! docker compose version >/dev/null 2>&1; then
    step "Устанавливаю Docker Compose" sh -c 'apt-get update -qq; apt-get install -y -qq docker-compose-plugin || apt-get install -y -qq docker-compose-v2' || return 1
  fi
}

# Останавливает RustDesk, установленный не этим скриптом (чужой docker / systemd)
stop_foreign() {
  local wd
  if has_docker; then
    for c in hbbs hbbr; do
      docker inspect "$c" >/dev/null 2>&1 || continue
      wd=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$c" 2>/dev/null)
      [ "$wd" = "$DIR" ] && continue
      docker rm -f "$c" >/dev/null 2>&1
    done
  fi
  for u in rustdesk-hbbs rustdesk-hbbr hbbs hbbr; do
    systemctl is-active --quiet "$u" 2>/dev/null && systemctl disable --now "$u" >/dev/null 2>&1
  done
  return 0
}

wait_key() { local i; for i in $(seq 1 30); do has_key && return 0; sleep 1; done; return 1; }
check_ports() {
  command -v ss >/dev/null 2>&1 || return 0
  local i
  for i in 1 2 3 4 5; do
    ss -lnt | grep -q ':21116 ' && ss -lnt | grep -q ':21117 ' && return 0; sleep 1
  done
  return 1
}

save_conf() {
  mkdir -p "$DIR"
  printf 'HOST=%s\nINSTALLED=%s\n' "$HOST" "$(date '+%Y-%m-%d %H:%M')" >"$CONF"
  cat >"$DIR/client-info.txt" <<EOF
RustDesk — данные для клиента
Сервер ID:    $HOST
Ретранслятор: $HOST
Сервер API:   (пусто)
Key:          $(get_key)
EOF
}

install_core() {
  section "Установка"
  ensure_docker || return 1
  stop_foreign
  write_compose; ok "Конфиг: ${DIM}$DIR/docker-compose.yml${R}"

  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    step "Открываю порты в ufw" sh -c 'ufw allow 21115:21117/tcp && ufw allow 21116/udp'
  else
    info "ufw не включён — порты на сервере не трогаю"
  fi

  step "Скачиваю образ RustDesk Server" dc pull     || return 1
  step "Запускаю hbbs и hbbr"           dc up -d    || return 1
  step "Проверяю ключ сервера"          wait_key    || return 1
  chmod 600 "$DATA/id_ed25519" 2>/dev/null
  step "Проверяю, что сервер слушает порты" check_ports || warn "Порты не открылись — смотри «Статус и логи»"
  save_conf
}

# Кладёт ключи из папки $1 в $DATA (сервер должен быть остановлен)
place_keys() {
  local src="$1"
  is_installed && has_docker && dc down >/dev/null 2>&1
  mkdir -p "$DATA"
  cp -f "$src/id_ed25519" "$src/id_ed25519.pub" "$DATA/" || return 1
  [ -s "$src/db_v2.sqlite3" ] && cp -f "$src/db_v2.sqlite3" "$DATA/"
  chmod 600 "$DATA/id_ed25519"
}

make_backup() { # make_backup [метка] → печатает путь
  local tag="${1:-backup}" f files
  f="$HOME/rustdesk-$tag-$(date +%Y%m%d-%H%M%S).tar.gz"
  files="id_ed25519 id_ed25519.pub"
  [ -s "$DATA/db_v2.sqlite3" ] && files="$files db_v2.sqlite3"
  # адрес сервера тоже кладём в архив, чтобы восстановление его предложило
  [ -f "$CONF" ] && cp -f "$CONF" "$DATA/autorustdesk.conf" && files="$files autorustdesk.conf"
  # shellcheck disable=SC2086
  tar czf "$f" -C "$DATA" $files 2>>"$LOG" || { rm -f "$DATA/autorustdesk.conf"; return 1; }
  rm -f "$DATA/autorustdesk.conf"
  chmod 600 "$f"; echo "$f"
}

# ================= итоговое окно =================
show_result() {
  local title="$1" key host C1=16 C2 W t
  key="$(get_key)"; host="$(saved_host)"; host="${host:-$(get_ip)}"
  C2=$(( ${#key} + 2 )); (( ${#host} + 2 > C2 )) && C2=$(( ${#host} + 2 )); (( C2 < 46 )) && C2=46
  W=$(( C1 + C2 + 1 ))

  line() { printf "  ${CYN}%s%s%s%s%s${R}\n" "$1" "$(repeat '═' $C1)" "$2" "$(repeat '═' $C2)" "$3"; }
  row()  { printf "  ${CYN}║${R} %s${CYN}║${R} %s%s${R}${CYN}║${R}\n" "$(pad "$1" $((C1-1)))" "$3" "$(pad "$2" $((C2-1)))"; }

  t="✔  $title"
  echo
  printf "  ${CYN}╔%s╗${R}\n" "$(repeat '═' $W)"
  printf "  ${CYN}║${R}${GRN}${B}%s${R}${CYN}║${R}\n" "$(pad "$(repeat ' ' $(( (W - ${#t}) / 2 )))$t" $W)"
  line "╠" "╦" "╣"
  row "Поле"         "Значение"      "$B"
  line "╠" "╬" "╣"
  row "Сервер ID"    "$host"         "$GRN$B"
  row "Ретранслятор" "$host"         "$GRN$B"
  row "Сервер API"   "оставь пустым" "$DIM"
  row "Key"          "$key"          "$YLW$B"
  line "╚" "╩" "╝"
}

client_help() {
  cat <<EOF

  ${B}Как подключиться${R}
  ${DIM}1.${R} Клиент RustDesk:  ${DIM}ПК / Android${R}  https://github.com/rustdesk/rustdesk/releases/latest
                       ${DIM}iPhone${R}        https://apps.apple.com/app/id1581225015
  ${DIM}2.${R} Настройки → Сеть → ID/Ретранслятор → впиши данные из таблицы
  ${DIM}3.${R} Внизу клиента должно появиться ${GRN}● Готово${R}

  ${YLW}!${R} Открой в фаерволе хостера (если есть): ${B}21115-21117/tcp${R} и ${B}21116/udp${R}
  ${DIM}Данные сохранены в $DIR/client-info.txt${R}
EOF
}

# ================= действия =================
act_install() {
  banner; section "Новая установка"
  local found=""
  if has_key; then
    ok "Найдена прошлая установка — ключ сохранится, клиенты перенастраивать не нужно"
  else
    found="$(bash -c "$FIND_KEYS" 2>/dev/null)"
    if [ -n "$found" ]; then
      echo
      info "На этом сервере уже есть RustDesk: ${B}$found${R}"
      info "Его ключ: ${YLW}$(tr -d '\n\r ' <"$found/id_ed25519.pub")${R}"
      hint "  Если использовать его, все клиенты продолжат работать без перенастройки."
      if yes_no "Использовать существующий ключ?" y; then
        place_keys "$found" && ok "Ключ скопирован в $DATA"
      else
        info "Будет создан новый ключ — клиенты придётся перенастроить"
      fi
      info "Старый экземпляр будет остановлен (порты заняты им), его файлы останутся на месте"
    fi
  fi
  choose_host install || { pause; return; }
  install_core || { die "Установка не завершена" "Подробности: $LOG"; return; }
  show_result "RustDesk сервер установлен"; client_help; pause
}

act_migrate() {
  banner; section "Перенос с другого сервера"
  hint "Скрипт подключится к старому серверу по SSH, сам найдёт ключи RustDesk"
  hint "и перенесёт их сюда. Клиенты продолжат работать с тем же ключом."
  echo
  command -v ssh >/dev/null 2>&1 || step "Устанавливаю SSH-клиент" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-client' || { pause; return; }

  local old port user sock rdir pub tmp target
  while :; do
    ask "IP или домен старого сервера:" old ""
    old="${old// /}"
    [ -z "$old" ] && { info "Отменено"; pause; return; }
    { is_ip "$old" || is_domain "$old"; } && break
    err "Не похоже на адрес сервера"
  done
  ask "Пользователь (Enter — root):" user "root"
  while :; do
    ask "SSH-порт (Enter — 22):" port "22"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] && break
    err "Порт — это число от 1 до 65535"
  done
  target="$user@$old"
  sock="/tmp/autorustdesk-ssh-$$"

  echo
  info "Подключаюсь к ${B}$target${R} — введи пароль ${B}от старого сервера${R}"
  hint "  (символы при вводе пароля не отображаются — это нормально)"
  if ! ssh -o ControlMaster=yes -o ControlPath="$sock" -o ControlPersist=300 \
           -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
           -p "$port" -fN "$target" </dev/tty; then
    die "Не удалось подключиться к $target:$port" "Проверь адрес, порт и пароль"; return
  fi
  ok "Подключено к старому серверу"
  rssh() { ssh -o ControlPath="$sock" -p "$port" "$target" "$@"; }

  info "Ищу RustDesk на старом сервере..."
  rdir="$(rssh "bash -s" <<<"$FIND_KEYS" 2>/dev/null | tail -n1)"
  if [ -z "$rdir" ]; then
    rssh -O exit >/dev/null 2>&1
    die "На старом сервере не найдены ключи RustDesk" \
        "Если ключи в нестандартной папке — скопируй id_ed25519* вручную в $DATA"; return
  fi
  pub="$(rssh "tr -d '\n\r ' < '$rdir/id_ed25519.pub'")"
  ok "Найдено: ${B}$rdir${R}"
  info "Ключ старого сервера: ${YLW}$pub${R}"
  rssh "test -s '$rdir/db_v2.sqlite3'" && info "База устройств: найдена, тоже перенесу"
  echo
  yes_no "Переносить этот сервер сюда?" y || { rssh -O exit >/dev/null 2>&1; info "Отменено"; pause; return; }

  tmp="$(mktemp -d)"
  step "Копирую ключи" scp -q -o ControlPath="$sock" -P "$port" \
       "$target:$rdir/id_ed25519" "$target:$rdir/id_ed25519.pub" "$tmp/" \
    || { rssh -O exit >/dev/null 2>&1; rm -rf "$tmp"; pause; return; }
  scp -q -o ControlPath="$sock" -P "$port" "$target:$rdir/db_v2.sqlite3" "$tmp/" >>"$LOG" 2>&1 \
    && ok "База устройств скопирована"

  if [ "$(tr -d '\n\r ' <"$tmp/id_ed25519.pub")" != "$pub" ]; then
    rssh -O exit >/dev/null 2>&1; rm -rf "$tmp"
    die "Скопированный ключ не совпадает с исходным — перенос прерван"; return
  fi
  ok "Ключ проверен"

  if has_key && [ "$(get_key)" != "$pub" ]; then
    local bk; bk="$(make_backup before-migrate)" && info "Текущий ключ этого сервера сохранён: ${DIM}$bk${R}"
  fi
  place_keys "$tmp" && ok "Ключи установлены"
  rm -rf "$tmp"

  choose_host migrate || { rssh -O exit >/dev/null 2>&1; pause; return; }
  if ! install_core; then
    rssh -O exit >/dev/null 2>&1; die "Установка не завершена" "Подробности: $LOG"; return
  fi

  if [ "$(get_key)" != "$pub" ]; then
    warn "Ключ после запуска отличается от старого! Проверь $DATA"
  fi

  echo
  hint "Старый сервер можно оставить работать, пока ты не переключишь DNS —"
  hint "так клиенты не потеряют связь ни на минуту."
  if yes_no "Остановить RustDesk на старом сервере сейчас?" n; then
    rssh "docker stop hbbs hbbr >/dev/null 2>&1; docker update --restart=no hbbs hbbr >/dev/null 2>&1; \
          for u in rustdesk-hbbs rustdesk-hbbr; do systemctl disable --now \$u >/dev/null 2>&1; done; true" \
      && ok "Старый сервер остановлен (файлы не удалены)"
  fi
  rssh -O exit >/dev/null 2>&1

  show_result "Перенос завершён"
  echo
  printf "  ${B}Что осталось сделать${R}\n"
  if is_ip "$HOST"; then
    printf "  ${YLW}›${R} В клиентах поменяй адрес сервера на ${B}%s${R} — ключ прежний\n" "$HOST"
  else
    printf "  ${YLW}›${R} Направь A-запись ${B}%s${R} на ${B}%s${R}\n" "$HOST" "$SERVER_IP"
    printf "  ${GRN}›${R} В клиентах ничего менять не нужно — ключ и адрес те же\n"
  fi
  printf "  ${DIM}›${R} ${DIM}Когда всё работает — старый сервер можно выключать${R}\n"
  pause
}

act_info() {
  banner
  has_key || { die "Сервер ещё не установлен" "Выбери пункт «Установить сервер»"; return; }
  show_result "Данные для подключения"
  if [ -z "$(saved_host)" ]; then
    echo; warn "Адрес сервера не сохранён — в таблице показан IP."
    hint "  Если ты используешь домен, выбери пункт 1: ключ сохранится, скрипт запомнит домен."
  fi
  client_help; pause
}

act_update() {
  banner; section "Обновление"
  is_installed || { die "Сервер не установлен"; return; }
  step "Скачиваю свежий образ"     dc pull   || { pause; return; }
  step "Перезапускаю контейнеры"   dc up -d  || { pause; return; }
  step "Удаляю старые образы"      docker image prune -f
  step "Проверяю порты"            check_ports
  ok "RustDesk обновлён, ключ и настройки сохранены"; pause
}

act_status() {
  banner; section "Статус"
  is_installed || { die "Сервер не установлен"; return; }
  if is_running; then ok "hbbs и hbbr ${GRN}работают${R}"; else err "Сервер ${RED}остановлен${R}"; fi
  info "Адрес: ${B}$(host_label)${R}"
  info "Папка: ${DIM}$DIR${R}"
  if command -v ss >/dev/null 2>&1; then
    for p in 21115 21116 21117; do
      if ss -lnt | grep -q ":$p "; then ok "Порт $p/tcp слушается"; else err "Порт $p/tcp не слушается"; fi
    done
    ss -lnu | grep -q ':21116 ' && ok "Порт 21116/udp слушается" || err "Порт 21116/udp не слушается"
  fi
  section "Последние логи"
  dc logs --tail 12 2>&1 | sed 's/^/    /'
  echo
  if yes_no "Перезапустить сервер?" n; then
    step "Перезапускаю" dc restart; step "Проверяю порты" check_ports
  fi
  pause
}

act_backup() {
  banner; section "Бэкап ключей"
  has_key || { die "Нечего сохранять — сервер не установлен"; return; }
  local f; f="$(make_backup backup)" || { die "Не удалось создать архив"; return; }
  ok "Бэкап создан: ${B}$f${R}"
  download_help "$f"
  echo
  warn "В архиве приватный ключ сервера — никому его не передавай"
  pause
}

ssh_port() {
  local p
  p=$(ss -lntp 2>/dev/null | awk '/sshd/ {print $4; exit}' | sed 's/.*://')
  [[ "$p" =~ ^[0-9]+$ ]] || p=22
  echo "$p"
}

# Собирает готовую команду для скачивания файла $1 на ПК
download_help() {
  local f="$1" os folder dest cmd ip port pflag="" name user
  ip="$(get_ip)"; port="$(ssh_port)"; user="$(id -un)"; name="$(basename "$f")"
  [ "$port" != 22 ] && pflag="-P $port "

  section "Скачать бэкап на компьютер"
  [ "$TTY" -eq 1 ] || { printf "    scp %s%s@%s:%s .\n" "$pflag" "$user" "$ip" "$f"; return; }

  echo
  item 1 "Windows"       ""
  item 2 "macOS"         ""
  item 3 "Linux"         ""
  echo
  ask "Какая система на компьютере? [1-3]:" os "1"
  case "$os" in 2|3) ;; *) os=1 ;; esac

  echo
  item 1 "Загрузки"      "Downloads"
  item 2 "Документы"     "Documents"
  item 3 "Рабочий стол"  "Desktop"
  item 4 "Своя папка"    "ввести путь"
  echo
  ask "Куда скачать? [1-4]:" folder "1"

  if [ "$os" = 1 ]; then
    case "$folder" in
      2) dest='$env:USERPROFILE\Documents' ;;
      3) dest='$env:USERPROFILE\Desktop' ;;
      4) ask "Путь на ПК (например D:\\Backups):" dest 'C:\RustDesk-backup' ;;
      *) dest='$env:USERPROFILE\Downloads' ;;
    esac
    cmd="scp ${pflag}${user}@${ip}:${f} \"${dest}\\${name}\""
  else
    case "$folder" in
      2) [ "$os" = 3 ] && dest='$(xdg-user-dir DOCUMENTS)' || dest='~/Documents' ;;
      3) [ "$os" = 3 ] && dest='$(xdg-user-dir DESKTOP)'   || dest='~/Desktop' ;;
      4) ask "Путь на ПК (например ~/Backups):" dest '~/rustdesk-backup' ;;
      *) [ "$os" = 3 ] && dest='$(xdg-user-dir DOWNLOAD)'  || dest='~/Downloads' ;;
    esac
    cmd="scp ${pflag}${user}@${ip}:${f} ${dest}/"
  fi

  echo
  case "$os" in
    1) hint "На компьютере открой PowerShell (Win+X → Терминал / PowerShell) и вставь:" ;;
    2) hint "На Mac открой Терминал (Cmd+Пробел → «Терминал») и вставь:" ;;
    3) hint "На компьютере открой терминал и вставь:" ;;
  esac
  echo
  printf "    ${CYN}${B}%s${R}\n" "$cmd"
  echo
  hint "Команда спросит пароль от этого сервера. Файл появится как ${name}"
  [ "$folder" = 4 ] && hint "Папка должна уже существовать на компьютере."
  [ "$os" = 1 ] && [ "$folder" = 3 ] && hint "Если рабочий стол в OneDrive — файл будет в OneDrive\\Desktop."
}

act_restore() {
  banner; section "Восстановление из бэкапа"
  local last f tmp kd
  last="$(ls -1t "$HOME"/rustdesk-*.tar.gz 2>/dev/null | head -n1)"
  hint "Загрузи архив на сервер (например: scp rustdesk-backup-*.tar.gz root@сервер:~)"
  echo
  if [ -n "$last" ]; then ask "Путь к архиву (Enter — $last):" f "$last"
  else ask "Путь к архиву:" f ""; fi
  f="${f/#\~/$HOME}"
  [ -f "$f" ] || { die "Файл не найден: $f"; return; }

  tmp="$(mktemp -d)"
  tar xzf "$f" -C "$tmp" 2>>"$LOG" || { rm -rf "$tmp"; die "Не удалось распаковать архив"; return; }
  kd="$(find "$tmp" -name id_ed25519.pub | head -n1)"
  [ -n "$kd" ] && kd="$(dirname "$kd")"
  if [ -z "$kd" ] || [ ! -s "$kd/id_ed25519" ]; then
    rm -rf "$tmp"; die "В архиве нет ключей RustDesk"; return
  fi
  info "Ключ из бэкапа: ${YLW}$(tr -d '\n\r ' <"$kd/id_ed25519.pub")${R}"
  yes_no "Восстановить этот ключ?" y || { rm -rf "$tmp"; pause; return; }
  if has_key; then local bk; bk="$(make_backup before-restore)" && info "Текущий ключ сохранён: ${DIM}$bk${R}"; fi
  place_keys "$kd" && ok "Ключи восстановлены"
  if [ -f "$kd/autorustdesk.conf" ] && [ -z "$(saved_host)" ]; then
    mkdir -p "$DIR"; cp -f "$kd/autorustdesk.conf" "$CONF"
  fi
  rm -rf "$tmp"

  choose_host install || { pause; return; }
  install_core || { die "Установка не завершена" "Подробности: $LOG"; return; }
  show_result "Сервер восстановлен"; client_help; pause
}

act_uninstall() {
  banner; section "Удаление сервера"
  is_installed || has_key || { die "Сервер не установлен — удалять нечего"; return; }

  warn "После удаления клиенты перестанут подключаться к этому серверу"
  echo
  item 1 "Остановить и удалить сервер" "ключ останется, можно вернуть"
  item 2 "Удалить полностью"           "сервер, образ, папка с ключом"
  item 0 "Отмена"                      ""
  echo
  local mode; ask "Выбери [0-2]:" mode "0"

  case "$mode" in
    1|2) ;;
    *) echo; info "Удаление отменено — сервер не тронут"; pause; return ;;
  esac

  echo
  if [ "$mode" = 2 ]; then
    warn "Будет удалена папка ${B}$DIR${R} вместе с приватным ключом."
    hint "  Без бэкапа восстановить ключ будет невозможно — все клиенты придётся перенастраивать."
    echo
    local a; ask "Для подтверждения напиши ${RED}удалить${R}${B}:" a ""
    a="$(printf '%s' "$a" | tr -d ' ')"
    if [ "$a" != "удалить" ] && [ "$a" != "Удалить" ] && [ "$a" != "УДАЛИТЬ" ]; then
      echo; info "Удаление отменено — сервер не тронут"; pause; return
    fi
  fi

  section "Удаление"
  if has_key; then
    local bk
    if bk="$(make_backup before-uninstall)"; then ok "Бэкап ключа сохранён: ${B}$bk${R}"
    else warn "Не удалось сделать бэкап ключа"; fi
  fi

  if has_docker && is_installed; then
    step "Останавливаю и удаляю контейнеры" dc down || warn "Контейнеры удалить не удалось, подробности в $LOG"
  fi
  stop_foreign

  [ "$mode" = 1 ] && rm -f "$DIR/docker-compose.yml"

  if [ "$mode" = 2 ]; then
    if has_docker && docker image inspect rustdesk/rustdesk-server:latest >/dev/null 2>&1; then
      step "Удаляю образ RustDesk" docker rmi rustdesk/rustdesk-server:latest
    fi
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
      step "Закрываю порты в ufw" sh -c 'ufw delete allow 21115:21117/tcp; ufw delete allow 21116/udp; true'
    fi
    rm -rf "$DIR" && ok "Папка ${DIM}$DIR${R} удалена"
  fi

  echo
  if [ "$mode" = 2 ]; then
    ok "${B}RustDesk полностью удалён${R}"
  else
    ok "${B}Сервер остановлен и удалён${R}"
    info "Ключ остался в ${DIM}$DATA${R} — пункт «Установить сервер» вернёт всё как было"
  fi
  [ -n "${bk:-}" ] && info "Бэкап ключа: ${DIM}$bk${R} — пункт 7 восстановит сервер из него"
  pause
}

# ================= меню =================
status_box() {
  local plain colored host W=50
  host="$(host_label)"
  if ! is_installed; then
    plain="○ Сервер не установлен"; colored="${DIM}○${R} Сервер не установлен"
  elif is_running; then
    plain="● Работает · ${host}"; colored="${GRN}●${R} ${B}Работает${R} · ${host}"
  else
    plain="● Остановлен · ${host}"; colored="${RED}●${R} ${B}Остановлен${R} · ${host}"
  fi
  (( ${#plain} + 4 > W )) && W=$(( ${#plain} + 4 ))
  printf "  ${DIM}┌%s┐${R}\n" "$(repeat '─' $W)"
  printf "  ${DIM}│${R}  %s%*s${DIM}│${R}\n" "$colored" $(( W - 2 - ${#plain} )) ''
  printf "  ${DIM}└%s┘${R}\n\n" "$(repeat '─' $W)"
}

item() { printf "   ${CYN}${B}%s${R}  %s  ${DIM}%s${R}\n" "$1" "$(pad "$2" 29)" "$3"; }

menu() {
  local c
  while :; do
    banner; status_box
    item 1 "Установить сервер"           "новая установка"
    item 2 "Перенести с другого сервера" "по SSH, с ключами"
    item 3 "Данные для подключения"      "сервер и ключ"
    echo
    item 4 "Обновить RustDesk"           "до последней версии"
    item 5 "Статус и логи"               "проверка, перезапуск"
    echo
    item 6 "Сделать бэкап ключей"        "архив .tar.gz"
    item 7 "Восстановить из бэкапа"      ""
    item 8 "Удалить сервер"              ""
    echo
    item 0 "Выход"                       ""
    echo
    ask "Выбери пункт:" c ""
    case "$c" in
      1) act_install ;;   2) act_migrate ;;  3) act_info ;;
      4) act_update ;;    5) act_status ;;   6) act_backup ;;
      7) act_restore ;;   8) act_uninstall ;;
      0|q|Q|й) echo; exit 0 ;;
      *) ;;
    esac
  done
}

# Установка без вопросов (аргументы или запуск без терминала)
auto_install() {
  banner
  HOST="${1:-}"
  [ -z "$HOST" ] && HOST="$(saved_host)"
  [ -z "$HOST" ] && HOST="$SERVER_IP"
  [ -z "$HOST" ] && { err "Не удалось определить IP сервера"; exit 1; }
  info "Адрес сервера: ${B}$HOST${R}"
  if ! has_key; then
    local found; found="$(bash -c "$FIND_KEYS" 2>/dev/null)"
    [ -n "$found" ] && place_keys "$found" && info "Использую существующий ключ из $found"
  fi
  install_core || exit 1
  show_result "RustDesk сервер установлен"; client_help; echo
}

# ================= старт =================
: >"$LOG"
if [ "$(id -u)" -ne 0 ]; then
  banner; err "Скрипт нужно запускать от root"; info "Выполни ${B}sudo -i${R} и запусти команду снова"; exit 1
fi
command -v apt-get >/dev/null 2>&1 || { banner; warn "Скрипт рассчитан на Ubuntu / Debian — на другой ОС может не сработать"; sleep 2; }
SERVER_IP=""; SERVER_IP="$(get_ip)"   # определяем один раз

case "${1:-}" in
  install) auto_install "${2:-}" ;;
  "")      if [ "$TTY" -eq 1 ]; then menu; else auto_install ""; fi ;;
  -h|--help) echo "Использование: install-rustdesk.sh [install [домен]]"; echo "$REPO" ;;
  *)       auto_install "$1" ;;   # совместимость: ... | bash -s -- rd.example.com
esac
