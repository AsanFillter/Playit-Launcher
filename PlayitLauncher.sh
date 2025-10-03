#!/usr/bin/env bash

#AsanFillter

set -e

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
LGREEN=$'\033[1;32m'
BOLD=$'\033[1m'
NC=$'\033[0m'
ORANGE=$'\033[38;5;208m'
BOX=$'\033[38;5;245m'

APP_NAME="PlayIt.gg"
APP_VER="v1.0.0"
SERVICE_NAME="playit"

clear_screen() { if command -v tput >/dev/null 2>&1; then tput reset; else clear; fi; }

get_ip() {
  if command -v curl >/dev/null 2>&1; then curl -s https://api.ipify.org || true; else hostname -I 2>/dev/null | awk '{print $1}'; fi
}

spinner() {
  local pid=$1; local msg=$2; local spin='|/-\\'; local i=0
  echo -ne "${CYAN}${msg}${NC} "
  while kill -0 "$pid" 2>/dev/null; do i=$(((i+1)%4)); printf "\r${CYAN}%s ${YELLOW}%s${NC}" "$msg" "${spin:$i:1}"; sleep 0.2; done
  wait "$pid"; local ec=$?
  if [ $ec -eq 0 ]; then echo -e "\r${GREEN}${msg} - done${NC}    "; else echo -e "\r${RED}${msg} - failed ($ec)${NC}"; fi
  return $ec
}

run() { ( bash -c "$1" ) & spinner $! "$2"; }

strip_ansi() { sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

visible_len() {
  local s="$1"
  echo -ne "$s" | strip_ansi | wc -c | tr -d ' '
}

print_box_line() {
  local width="$1"; shift
  local line="$1"
  local vis; vis=$(visible_len "$line")
  local pad=$((width - vis))
  if [ "$pad" -lt 0 ]; then pad=0; fi
  printf "│%s%*s│\n" "$line" "$pad" ""
}

banner() {
  echo -e "${LGREEN}"
  cat << 'B'
 /$$$$$$                                /$$$$$$$$ /$$ /$$ /$$   /$$
 /$$__  $$                              | $$_____/|__/| $$| $$  | $$
| $$  \ $$  /$$$$$$$  /$$$$$$  /$$$$$$$ | $$       /$$| $$| $$ /$$$$$$    /$$$$$$   /$$$$$$
| $$$$$$$$ /$$_____/ |____  $$| $$__  $$| $$$$$   | $$| $$| $$|_  $$_/   /$$__  $$ /$$__  $$
| $$__  $$|  $$$$$$   /$$$$$$$| $$  \ $$| $$__/   | $$| $$| $$  | $$    | $$$$$$$$| $$  \__/
| $$  | $$ \____  $$ /$$__  $$| $$  | $$| $$      | $$| $$| $$  | $$ /$$| $$_____/| $$
| $$  | $$ /$$$$$$$/|  $$$$$$$| $$  | $$| $$      | $$| $$| $$  |  $$$$/|  $$$$$$$| $$
|__/  |__/|_______/  \_______/|__/  |__/|__/      |__/|__/|__/   \___/   \_______/|__/
B
  echo -e "${NC}"
  local width=68
  local title="${APP_NAME} Installation Setup"
  local ip="$(get_ip)"
  local status="Not Installed"; if command -v ${SERVICE_NAME} >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -q "^${SERVICE_NAME}\.service$"; then status="Installed"; fi
  local tlen=${#title}
  if [ $tlen -gt $width ]; then title=${title:0:$width}; tlen=${#title}; fi
  local left=$(( (width - tlen) / 2 ))
  local right=$(( width - tlen - left ))
  echo -e "${BOX}"
  printf "┌%s┐\n" "$(printf '─%.0s' $(seq 1 $width))"
  printf "│%s%s%s│\n" "$(printf '%*s' $left)" "${YELLOW}${title}${BOX}" "$(printf '%*s' $right)"
  printf "│%-${width}s│\n" ""
  print_box_line "$width" " • Version: ${APP_VER}"
  print_box_line "$width" " • Server IP: ${WHITE}${ip}${BOX}"
  print_box_line "$width" " • Playit Status: ${status}"
  print_box_line "$width" " • TelegramChannel: ${ORANGE}@AsanFillter${BOX}"
  printf "│%-${width}s│\n" ""
  printf "└%s┘\n" "$(printf '─%.0s' $(seq 1 $width))"
  echo -e "${NC}"
}

ensure_root() { if [ "$EUID" -ne 0 ]; then echo -e "${RED}Run as root or with sudo.${NC}"; exit 1; fi; }

invalid_choice() {
  local range="$1"
  echo -e "${RED}Invalid input. Please enter a number between ${range}.${NC}"
  echo ""
  read -rp "Press Enter to continue... " _
}

is_playit_installed() {
  command -v playit >/dev/null 2>&1 && return 0
  [ -x "/opt/playit/playit" ] && return 0
  service_present && return 0
  if command -v dpkg >/dev/null 2>&1; then dpkg -l | awk '{print $2}' | grep -qx "playit" && return 0; fi
  return 1
}

service_present() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null | awk '{print $1}' | grep -q "^${SERVICE_NAME}\.service$" && return 0
    [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] && return 0
    [ -f "/lib/systemd/system/${SERVICE_NAME}.service" ] && return 0
  fi
  return 1
}

require_service_or_back() {
  if service_present; then return 0; fi
  echo -e "${YELLOW}Playit service is not installed. Please install it first${NC}"
  echo -ne "${WHITE}Press Enter to return to the menu....${NC} "
  read -r _
  return 1
}

service_active() {
  systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null
}

start_service_if_needed() {
  if service_active; then
    echo -e "${YELLOW}Service is already running.${NC}"
    return 0
  fi
  ensure_root
  if systemctl start ${SERVICE_NAME} 2>/dev/null; then
    echo -e "${GREEN}Service started.${NC}"
  else
    echo -e "${RED}Failed to start service.${NC}"
  fi
}

stop_service_if_needed() {
  if ! service_active; then
    echo -e "${YELLOW}Service is already stopped.${NC}"
    return 0
  fi
  ensure_root
  if systemctl stop ${SERVICE_NAME} 2>/dev/null; then
    echo -e "${GREEN}Service stopped.${NC}"
  else
    echo -e "${RED}Failed to stop service.${NC}"
  fi
}

install_playit() {
  ensure_root
  clear_screen
  echo -e "${BOLD}${WHITE}Installing Playit service${NC}"
  run "curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null" "Adding repository key"
  run "echo \"deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./\" | tee /etc/apt/sources.list.d/playit-cloud.list >/dev/null" "Adding repository"
  run "apt update -y" "Updating package index"
  run "DEBIAN_FRONTEND=noninteractive apt install -y playit" "Installing playit"
  run "systemctl daemon-reload" "Reloading systemd"
  run "systemctl enable ${SERVICE_NAME} --now" "Starting service"
  echo -e "${GREEN}Playit installed.${NC}"
  echo -e "${YELLOW}First-time claim required. Starting interactive claim now...${NC}"
  first_claim_interactive
}

service_menu() {
  while true; do
    clear_screen; banner
    echo -e " ${LGREEN}[1]${NC} ${LGREEN}Start Playit Service${NC}"
    echo -e " ${YELLOW}[2]${NC} ${YELLOW}Stop Playit Service${NC}"
    echo -e " ${CYAN}[3]${NC} Restart Playit Service"
    echo -e " ${WHITE}[4]${NC} Playit Status"
    echo -e " ${WHITE}[5]${NC} Recent Logs"
    echo -e " ${WHITE}[6]${NC} Back to menu"
    echo ""
    echo -ne "${CYAN}Choose [1-6]:${NC} "
    read -r s
    if [[ ! "$s" =~ ^[1-6]$ ]]; then invalid_choice "1-6"; continue; fi
    case "$s" in
      1)
        if require_service_or_back; then start_service_if_needed; read -rp "Press Enter..."; fi ;;
      2)
        if require_service_or_back; then stop_service_if_needed; read -rp "Press Enter..."; fi ;;
      3)
        if require_service_or_back; then ensure_root; systemctl restart ${SERVICE_NAME} || true; echo -e "${GREEN}Restarted.${NC}"; read -rp "Press Enter..."; fi ;;
      4)
        if require_service_or_back; then systemctl status ${SERVICE_NAME} --no-pager || true; read -rp "Press Enter..."; fi ;;
      5)
        if require_service_or_back; then journalctl -u ${SERVICE_NAME} -n 200 --no-pager || true; read -rp "Press Enter..."; fi ;;
      6) return ;;
      *) ;;
    esac
  done
}

claim_from_binary() {
  ensure_root
  systemctl stop ${SERVICE_NAME} >/dev/null 2>&1 || true
  local cap_file="/tmp/playit_claim_capture.log"
  rm -f "$cap_file" >/dev/null 2>&1 || true
  (playit > "$cap_file" 2>&1) & pid=$!
  sleep 10
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" 2>/dev/null || true
  if ! grep -q -Eo 'https://playit\.gg/claim/[A-Za-z0-9]+' "$cap_file"; then
    if command -v timeout >/dev/null 2>&1; then
      timeout 120s playit > "$cap_file" 2>&1 || true
    else
      (playit > "$cap_file" 2>&1) & pid=$!
      sleep 120
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" 2>/dev/null || true
    fi
  fi
  systemctl start ${SERVICE_NAME} >/dev/null 2>&1 || true
  grep -Eo 'https://playit\.gg/claim/[A-Za-z0-9]+' "$cap_file" | head -n1 || true
}

show_claim() {
  local follow=$1
  clear_screen; banner
  echo -e "${BOLD}${WHITE}Claim URL / Code${NC}"
  if [ "${follow}" = "1" ]; then
    echo -e "${YELLOW}Waiting for service output (auto-stops on first match, max 120s).${NC}"
    local line
    if command -v timeout >/dev/null 2>&1; then
      line=$(timeout 120s bash -c "journalctl -u ${SERVICE_NAME} -f 2>/dev/null | grep -m1 -E 'https://playit\\.gg/claim/[A-Za-z0-9]+'" || true)
    else
      line=$(bash -c "journalctl -u ${SERVICE_NAME} -f 2>/dev/null | grep -m1 -E 'https://playit\\.gg/claim/[A-Za-z0-9]+'" || true)
    fi
    if [ -z "$line" ]; then
      echo -e "${YELLOW}Trying safe capture...${NC}"
      line=$(claim_from_binary)
    fi
    if [ -n "$line" ]; then
      echo -e "${GREEN}$line${NC}"
      echo -e "\n${CYAN}Service remains running in background.${NC}"
    else
      echo -e "${RED}Could not detect claim link. Try running 'playit' manually or check logs with 'journalctl -u playit'.${NC}"
    fi
  else

    echo -e "${YELLOW}Attempting to run playit to capture claim...${NC}"
    local link
    link=$(claim_from_binary)
    if [ -n "$link" ]; then
      echo -e "${GREEN}${link}${NC}"
      echo -e "\n${CYAN}Service remains running in background.${NC}"
    else
      echo -e "${RED}Could not detect claim link automatically. Please run 'playit' manually in a terminal to see the claim URL.${NC}"
    fi
  fi
}

update_playit() {
  ensure_root
  clear_screen; banner
  if ! is_playit_installed; then
    echo -e "${RED}Playit is not installed. Please install it first.${NC}"
    read -rp "Press Enter..."
    return
  fi
  echo -e "${BOLD}${WHITE}Checking for Playit updates...${NC}"
  local policy_out
  policy_out=$(apt-cache policy playit 2>/dev/null || echo "Error: Could not check policy")
  local installed_ver=$(echo "$policy_out" | grep "Installed:" | awk '{print $2}' | head -1 || echo "unknown")
  local candidate_ver=$(echo "$policy_out" | grep "Candidate:" | awk '{print $2}' | head -1 || echo "unknown")
  if [ "$installed_ver" = "$candidate_ver" ] || [ "$candidate_ver" = "unknown" ]; then
    echo -e "${YELLOW}No updates available. Current version: ${installed_ver}${NC}"
    echo ""
    read -rp "Press Enter..."
    return
  fi
  echo -e "${GREEN}Update available: ${installed_ver} -> ${candidate_ver}${NC}"
  read -rp "Proceed with update? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    run "apt update -y" "Updating package index"
    run "DEBIAN_FRONTEND=noninteractive apt install -y --only-upgrade playit" "Updating playit"
    echo -e "${GREEN}Update complete. New version: ${candidate_ver}${NC}"
    systemctl restart ${SERVICE_NAME} >/dev/null 2>&1 || true
  else
    echo -e "${YELLOW}Update skipped.${NC}"
  fi
  read -rp "Press Enter..."
}

remove_playit() {
  ensure_root
  if ! is_playit_installed; then
    echo -e "${RED}Playit is not installed. Nothing to remove.${NC}"
    read -rp "Press Enter..."
    return
  fi
  run "systemctl disable ${SERVICE_NAME} --now || true" "Stopping service"
  run "apt remove -y playit || true" "Removing package"
  run "rm -f /etc/apt/sources.list.d/playit-cloud.list || true" "Cleaning repo"
  echo -e "${YELLOW}Removed.${NC}"
  read -rp "Press Enter..."
}

warning_box() {
  local width=90
  local title="IMPORTANT INSTRUCTIONS"
  local tlen=${#title}
  if [ $tlen -gt $width ]; then title=${title:0:$width}; tlen=${#title}; fi
  local left=$(( (width - tlen) / 2 ))
  local right=$(( width - tlen - left ))
  echo -e "${RED}"
  printf "┌%s┐\n" "$(printf '─%.0s' $(seq 1 $width))"
  printf "│%s%s%s│\n" "$(printf '%*s' $left)" "${YELLOW}${title}${RED}" "$(printf '%*s' $right)"
  printf "│%-${width}s│\n" ""
  print_box_line "$width" " ${YELLOW}Open the shown Claim link in your browser to link the agent, then press Ctrl+C to exit.${RED}"
  local text1="${YELLOW}If prompted after Ctrl+C, type 'y' to close the program.${RED}"
  local vis1=$(visible_len "$text1")
  local total_pad1=$((width - vis1))
  local left_pad1=$((total_pad1 / 2))
  local centered_line1="$(printf '%*s' $left_pad1 '')$text1"
  print_box_line "$width" "$centered_line1"
  local text2="${YELLOW}After exit, the service will be enabled and started automatically.${RED}"
  local vis2=$(visible_len "$text2")
  local total_pad2=$((width - vis2))
  local left_pad2=$((total_pad2 / 2))
  local centered_line2="$(printf '%*s' $left_pad2 '')$text2"
  print_box_line "$width" "$centered_line2"
  printf "│%-${width}s│\n" ""
  printf "└%s┘\n" "$(printf '─%.0s' $(seq 1 $width))"
  echo -e "${NC}"
}

first_claim_interactive() {
  ensure_root
  clear_screen
  warning_box
  sleep 5
  systemctl stop ${SERVICE_NAME} >/dev/null 2>&1 || true
  local bin="/opt/playit/playit"
  [ -x "$bin" ] || bin="$(command -v playit 2>/dev/null || echo /opt/playit/playit)"
  echo ""
  "$bin" || true
  sleep 1
  echo ""
  read -rp "Press Enter to enable and start Playit as a service... " _
  systemctl enable --now ${SERVICE_NAME} || true
  sleep 1
  local en act
  en=$(systemctl is-enabled ${SERVICE_NAME} 2>/dev/null || true)
  act=$(systemctl is-active ${SERVICE_NAME} 2>/dev/null || true)
  echo -e "\n${WHITE}Enabled:${NC} ${YELLOW}${en}${NC}"
  echo -e "${WHITE}Active:${NC}  ${YELLOW}${act}${NC}\n"
  echo -e "${CYAN}Recent logs:${NC}"
  journalctl -u ${SERVICE_NAME} -n 20 --no-pager 2>/dev/null || true
  echo ""
  read -rp "Press Enter to return to main menu... " _
}

main_menu() {
  while true; do
    clear_screen; banner
    echo -e " ${LGREEN}[1]${NC} ${LGREEN}Install ${APP_NAME}${NC}"
    echo -e " ${YELLOW}[2]${NC} ${YELLOW}Manage Service${NC}"
    echo -e " ${WHITE}[3]${NC} Show Claim (recent)"
    echo -e " ${WHITE}[4]${NC} First-time Claim (interactive)"
    echo -e " ${WHITE}[5]${NC} Update Playit"
    echo -e " ${WHITE}[6]${NC} Remove Playit"
    echo -e " ${WHITE}[7]${NC} Exit"
    echo ""
    echo -ne "${CYAN}Please enter your choice [1-7]: ${NC}"
    read -r ch
    if [[ ! "$ch" =~ ^[1-7]$ ]]; then invalid_choice "1-7"; continue; fi
    case "$ch" in
      1)
        if is_playit_installed; then
          echo -e "${YELLOW}Playit already appears to be installed. Skipping installation.${NC}"
          echo ""
          echo -ne "${WHITE}Press Enter to return to the menu....${NC} "
          read -r _
        else
          install_playit
        fi ;;
      2) service_menu ;;
      3) show_claim 0; read -rp "Press Enter..." ;;
      4) first_claim_interactive ;;
      5) update_playit ;;
      6) remove_playit ;;
      7) exit 0 ;;
      *) ;;
    esac
  done
}

main_menu