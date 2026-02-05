#!/bin/bash

# ============================================
# DOTFILES - INSTALACIÓN COMPLETA AUTOMATIZADA
# Instala paquetes + aplica configuraciones vía Stow
# ============================================

set -e

# ============================================
# CONFIGURACIÓN Y VARIABLES GLOBALES
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
PACKAGES_DIR="$SCRIPT_DIR/packages"
LOG_FILE="$SCRIPT_DIR/install.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Modo de operación
AUTO_MODE=false
SKIP_PACKAGES=false
SKIP_STOW=false
SELECTIVE_INSTALL=""

# ============================================
# FUNCIONES DE UTILIDAD
# ============================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# ============================================
# DETECCIÓN DE SISTEMA
# ============================================

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros)
                echo "arch"
                ;;
            debian|ubuntu|pop|linuxmint|elementary|zorin)
                echo "debian"
                ;;
            fedora|rhel|centos|rocky|alma)
                echo "fedora"
                ;;
            opensuse*|suse*)
                echo "opensuse"
                ;;
            void)
                echo "void"
                ;;
            gentoo)
                echo "gentoo"
                ;;
            nixos)
                echo "nixos"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

detect_desktop_environment() {
    if [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION"
    elif [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
    else
        echo "unknown"
    fi
}

# ============================================
# INSTALACIÓN DE DEPENDENCIAS BÁSICAS
# ============================================

install_stow() {
    log "Verificando GNU Stow..."
    
    if command -v stow &> /dev/null; then
        success "GNU Stow ya está instalado"
        return 0
    fi
    
    log "Instalando GNU Stow..."
    
    case $DISTRO in
        arch)
            sudo pacman -S --needed --noconfirm stow
            ;;
        debian)
            sudo apt-get update
            sudo apt-get install -y stow
            ;;
        fedora)
            sudo dnf install -y stow
            ;;
        opensuse)
            sudo zypper install -y stow
            ;;
        void)
            sudo xbps-install -Sy stow
            ;;
        gentoo)
            sudo emerge --ask=n app-admin/stow
            ;;
        *)
            error "No se pudo instalar Stow automáticamente. Instálalo manualmente."
            exit 1
            ;;
    esac
    
    success "GNU Stow instalado"
}

install_aur_helper() {
    if [ "$DISTRO" != "arch" ]; then
        return 0
    fi
    
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        success "yay encontrado como AUR helper"
        return 0
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
        success "paru encontrado como AUR helper"
        return 0
    fi
    
    log "Instalando yay (AUR helper)..."
    
    # Instalar dependencias
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Clonar y compilar yay
    YAY_DIR="/tmp/yay-install-$$"
    git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    rm -rf "$YAY_DIR"
    
    AUR_HELPER="yay"
    success "yay instalado correctamente"
}

# ============================================
# INSTALACIÓN DE PAQUETES POR CATEGORÍA
# ============================================

install_package_list() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        warning "Archivo no encontrado: $file"
        return 0
    fi
    
    # Filtrar líneas vacías y comentarios
    local packages=$(grep -v '^\s*#' "$file" | grep -v '^\s*$' | tr '\n' ' ')
    
    if [ -z "$packages" ]; then
        warning "Lista vacía: $description"
        return 0
    fi
    
    log "Instalando: $description"
    echo -e "${CYAN}Paquetes:${NC} $packages"
    
    case $DISTRO in
        arch)
            sudo pacman -S --needed --noconfirm $packages
            ;;
        debian)
            sudo apt-get update
            sudo apt-get install -y $packages
            ;;
        fedora)
            sudo dnf install -y $packages
            ;;
        opensuse)
            sudo zypper install -y $packages
            ;;
        void)
            sudo xbps-install -Sy $packages
            ;;
        gentoo)
            sudo emerge --ask=n $packages
            ;;
    esac
    
    success "$description completado"
}

install_aur_packages() {
    if [ "$DISTRO" != "arch" ] || [ -z "$AUR_HELPER" ]; then
        return 0
    fi
    
    local file="$PACKAGES_DIR/aur.txt"
    
    if [ ! -f "$file" ]; then
        warning "No hay lista de paquetes AUR"
        return 0
    fi
    
    local packages=$(grep -v '^\s*#' "$file" | grep -v '^\s*$' | tr '\n' ' ')
    
    if [ -z "$packages" ]; then
        return 0
    fi
    
    log "Instalando paquetes AUR..."
    echo -e "${CYAN}Paquetes AUR:${NC} $packages"
    
    $AUR_HELPER -S --needed --noconfirm $packages
    
    success "Paquetes AUR instalados"
}

install_all_packages() {
    print_header "INSTALACIÓN DE PAQUETES DEL SISTEMA"
    
    # Actualizar sistema primero
    log "Actualizando sistema..."
    case $DISTRO in
        arch)
            sudo pacman -Syu --noconfirm
            ;;
        debian)
            sudo apt-get update && sudo apt-get upgrade -y
            ;;
        fedora)
            sudo dnf upgrade -y
            ;;
        opensuse)
            sudo zypper dup -y
            ;;
        void)
            sudo xbps-install -Syu
            ;;
        gentoo)
            sudo emerge --sync
            sudo emerge -uDN @world
            ;;
    esac
    success "Sistema actualizado"
    
    # Instalar por categorías
    install_package_list "$PACKAGES_DIR/base.txt" "Herramientas base"
    install_package_list "$PACKAGES_DIR/$DISTRO.txt" "Paquetes específicos de $DISTRO"
    install_package_list "$PACKAGES_DIR/xorg.txt" "Xorg y display server"
    install_package_list "$PACKAGES_DIR/bspwm.txt" "BSPWM y dependencias"
    install_package_list "$PACKAGES_DIR/terminal.txt" "Terminales y shells"
    install_package_list "$PACKAGES_DIR/development.txt" "Herramientas de desarrollo"
    install_package_list "$PACKAGES_DIR/media.txt" "Multimedia"
    install_package_list "$PACKAGES_DIR/fonts.txt" "Fuentes"
    install_package_list "$PACKAGES_DIR/apps.txt" "Aplicaciones de usuario"
    
    # Instalar AUR si es Arch
    install_aur_packages
    
    success "Todas las categorías de paquetes instaladas"
}

# ============================================
# BACKUP DE CONFIGURACIONES EXISTENTES
# ============================================

backup_existing_configs() {
    print_header "BACKUP DE CONFIGURACIONES EXISTENTES"
    
    local backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log "Creando backup en: $backup_dir"
    
    # Función para backup seguro
    backup_if_exists() {
        local src="$1"
        local name="$2"
        
        if [ -e "$src" ] && [ ! -L "$src" ]; then
            cp -r "$src" "$backup_dir/"
            rm -rf "$src"
            log "Respaldado: $name"
        fi
    }
    
    # Backup de .config
    for pkg in $(ls "$DOTFILES_DIR" 2>/dev/null); do
        if [ -d "$HOME/.config/$pkg" ]; then
            backup_if_exists "$HOME/.config/$pkg" ".config/$pkg"
        fi
    done
    
    # Backup de archivos en home
    backup_if_exists "$HOME/.zshrc" ".zshrc"
    backup_if_exists "$HOME/.p10k.zsh" ".p10k.zsh"
    backup_if_exists "$HOME/.bashrc" ".bashrc"
    backup_if_exists "$HOME/.bash_profile" ".bash_profile"
    backup_if_exists "$HOME/.gitconfig" ".gitconfig"
    backup_if_exists "$HOME/.tmux.conf" ".tmux.conf"
    backup_if_exists "$HOME/.xinitrc" ".xinitrc"
    backup_if_exists "$HOME/.Xresources" ".Xresources"
    
    # Backup de directorios especiales
    backup_if_exists "$HOME/.local/bin" ".local/bin"
    backup_if_exists "$HOME/.themes" ".themes"
    backup_if_exists "$HOME/.icons" ".icons"
    
    success "Backup completado en: $backup_dir"
}

# ============================================
# APLICACIÓN DE CONFIGURACIONES CON STOW
# ============================================

apply_stow_configs() {
    print_header "APLICACIÓN DE CONFIGURACIONES (STOW)"
    
    cd "$DOTFILES_DIR"
    
    # Detectar paquetes disponibles
    local packages=()
    for dir in */; do
        if [ -d "$dir" ]; then
            packages+=("${dir%/}")
        fi
    done
    
    log "Paquetes de configuración encontrados: ${#packages[@]}"
    
    # Si es modo selectivo, filtrar
    if [ -n "$SELECTIVE_INSTALL" ]; then
        IFS=',' read -ra SELECTED <<< "$SELECTIVE_INSTALL"
        local filtered=()
        for pkg in "${packages[@]}"; do
            for sel in "${SELECTED[@]}"; do
                if [ "$pkg" == "$sel" ]; then
                    filtered+=("$pkg")
                    break
                fi
            done
        done
        packages=("${filtered[@]}")
        log "Modo selectivo: ${packages[*]}"
    fi
    
    # Orden de instalación importante
    local priority_order=("x11" "git" "zsh" "bash" "bspwm" "sxhkd" "picom" "dunst" "polybar" "rofi" "kitty" "nvim" "tmux" "ranger" "mpd" "themes" "bin" "fonts")
    local ordered_packages=()
    local remaining_packages=()
    
    # Primero los prioritarios
    for priority in "${priority_order[@]}"; do
        for pkg in "${packages[@]}"; do
            if [ "$pkg" == "$priority" ]; then
                ordered_packages+=("$pkg")
                break
            fi
        done
    done
    
    # Luego el resto
    for pkg in "${packages[@]}"; do
        local is_priority=false
        for priority in "${priority_order[@]}"; do
            if [ "$pkg" == "$priority" ]; then
                is_priority=true
                break
            fi
        done
        if [ "$is_priority" == false ]; then
            remaining_packages+=("$pkg")
        fi
    done
    
    ordered_packages+=("${remaining_packages[@]}")
    
    # Aplicar stow
    local failed_packages=()
    
    for pkg in "${ordered_packages[@]}"; do
        log "Aplicando configuración: $pkg"
        
        if stow -R "$pkg" 2>>"$LOG_FILE"; then
            success "$pkg configurado"
            
            # Permisos especiales
            case $pkg in
                bspwm)
                    [ -f "$HOME/.config/bspwm/bspwmrc" ] && chmod +x "$HOME/.config/bspwm/bspwmrc"
                    [ -d "$HOME/.config/bspwm/scripts" ] && chmod +x "$HOME/.config/bspwm/scripts/"*.sh 2>/dev/null || true
                    ;;
                sxhkd)
                    [ -f "$HOME/.config/sxhkd/sxhkdrc" ] && chmod +x "$HOME/.config/sxhkd/sxhkdrc" 2>/dev/null || true
                    ;;
                polybar)
                    [ -f "$HOME/.config/polybar/launch.sh" ] && chmod +x "$HOME/.config/polybar/launch.sh"
                    [ -d "$HOME/.config/polybar/scripts" ] && chmod -R +x "$HOME/.config/polybar/scripts/" 2>/dev/null || true
                    ;;
                bin)
                    [ -d "$HOME/.local/bin" ] && chmod -R +x "$HOME/.local/bin/" 2>/dev/null || true
                    ;;
            esac
        else
            error "Falló la configuración de $pkg"
            failed_packages+=("$pkg")
        fi
    done
    
    # Reporte final
    if [ ${#failed_packages[@]} -eq 0 ]; then
        success "Todas las configuraciones aplicadas correctamente"
    else
        warning "Algunos paquetes fallaron: ${failed_packages[*]}"
    fi
}

# ============================================
# CONFIGURACIÓN POST-INSTALACIÓN
# ============================================

post_installation() {
    print_header "CONFIGURACIÓN POST-INSTALACIÓN"
    
    # Zsh como shell por defecto
    if command -v zsh &> /dev/null && [ "$SHELL" != "$(which zsh)" ]; then
        log "Configurando Zsh como shell por defecto..."
        chsh -s "$(which zsh)" || warning "No se pudo cambiar el shell (ignorando)"
    fi
    
    # Instalar plugins de Zsh
    if [ -f "$HOME/.zshrc" ]; then
        log "Instalando plugins de Zsh..."
        
        mkdir -p "$HOME/.zsh"
        
        # zsh-autosuggestions
        if [ ! -d "$HOME/.zsh/zsh-autosuggestions" ]; then
            git clone https://github.com/zsh-users/zsh-autosuggestions \
                "$HOME/.zsh/zsh-autosuggestions" 2>/dev/null && \
                success "zsh-autosuggestions instalado" || \
                warning "No se pudo instalar zsh-autosuggestions"
        fi
        
        # zsh-syntax-highlighting
        if [ ! -d "$HOME/.zsh/zsh-syntax-highlighting" ]; then
            git clone https://github.com/zsh-users/zsh-syntax-highlighting \
                "$HOME/.zsh/zsh-syntax-highlighting" 2>/dev/null && \
                success "zsh-syntax-highlighting instalado" || \
                warning "No se pudo instalar zsh-syntax-highlighting"
        fi
        
        # Powerlevel10k
        if [ ! -d "$HOME/.zsh/powerlevel10k" ]; then
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
                "$HOME/.zsh/powerlevel10k" 2>/dev/null && \
                success "Powerlevel10k instalado" || \
                warning "No se pudo instalar Powerlevel10k"
        fi
    fi
    
    # Configurar Git si no está configurado
    if command -v git &> /dev/null; then
        if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
            warning "Git no tiene configurado user.name"
            if [ "$AUTO_MODE" == false ]; then
                read -p "Introduce tu nombre para Git: " git_name
                [ -n "$git_name" ] && git config --global user.name "$git_name"
            fi
        fi
        
        if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
            warning "Git no tiene configurado user.email"
            if [ "$AUTO_MODE" == false ]; then
                read -p "Introduce tu email para Git: " git_email
                [ -n "$git_email" ] && git config --global user.email "$git_email"
            fi
        fi
    fi
    
    # Crear directorios necesarios
    log "Creando directorios de usuario..."
    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/Pictures/Wallpapers"
    mkdir -p "$HOME/Downloads"
    mkdir -p "$HOME/Documents"
    mkdir -p "$HOME/Projects"
    mkdir -p "$HOME/.cache/zsh"
    
    # Configurar fondo de pantalla si existe nitrogen
    if command -v nitrogen &> /dev/null && [ -d "$HOME/Pictures/Wallpapers" ]; then
        if [ -f "$HOME/Pictures/Wallpapers/default.jpg" ]; then
            nitrogen --set-zoom-fill "$HOME/Pictures/Wallpapers/default.jpg" 2>/dev/null || true
        fi
    fi
    
    success "Post-instalación completada"
}

# ============================================
# VERIFICACIÓN FINAL
# ============================================

verify_installation() {
    print_header "VERIFICACIÓN DE LA INSTALACIÓN"
    
    local checks=(
        "bspwm:bspwm --version"
        "sxhkd:sxhkd -v"
        "polybar:polybar --version"
        "kitty:kitty --version"
        "rofi:rofi -v"
        "zsh:zsh --version"
        "nvim:nvim --version"
        "git:git --version"
        "picom:picom --version"
    )
    
    local all_good=true
    
    for check in "${checks[@]}"; do
        IFS=':' read -r name cmd <<< "$check"
        if eval "$cmd" &>/dev/null; then
            success "$name instalado correctamente"
        else
            error "$name no encontrado o no funciona"
            all_good=false
        fi
    done
    
    # Verificar symlinks
    log "Verificando symlinks de configuración..."
    local symlink_checks=(".zshrc" ".config/bspwm" ".config/sxhkd" ".config/polybar" ".config/kitty")
    for link in "${symlink_checks[@]}"; do
        if [ -L "$HOME/$link" ]; then
            success "Symlink correcto: ~/$link"
        else
            warning "Symlink no encontrado: ~/$link"
        fi
    done
    
    if [ "$all_good" == true ]; then
        success "Verificación completada exitosamente"
    else
        warning "Algunos componentes no se instalaron correctamente. Revisa el log: $LOG_FILE"
    fi
}

# ============================================
# MENÚ INTERACTIVO
# ============================================

show_menu() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     INSTALADOR DE DOTFILES v2.0      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Distribución detectada: ${YELLOW}$DISTRO${NC}"
    echo -e "Entorno actual: ${YELLOW}$(detect_desktop_environment)${NC}"
    echo ""
    echo "Opciones:"
    echo "  1) Instalación COMPLETA (recomendado)"
    echo "  2) Solo instalar paquetes del sistema"
    echo "  3) Solo aplicar configuraciones (Stow)"
    echo "  4) Instalación selectiva (elegir paquetes)"
    echo "  5) Desinstalar configuraciones"
    echo "  6) Crear backup de configuración actual"
    echo "  7) Ver log de instalación"
    echo "  8) Salir"
    echo ""
}

# ============================================
# MODO AUTOMÁTICO (UNATTENDED)
# ============================================

run_auto_mode() {
    print_header "MODO AUTOMÁTICO - INSTALACIÓN COMPLETA"
    
    log "Iniciando instalación automática..."
    log "Distribución: $DISTRO"
    log "Dotfiles: $DOTFILES_DIR"
    
    install_stow
    install_aur_helper
    install_all_packages
    backup_existing_configs
    apply_stow_configs
    post_installation
    verify_installation
    
    print_header "INSTALACIÓN COMPLETADA"
    echo -e "${GREEN}Tu sistema está configurado y listo para usar.${NC}"
    echo ""
    echo -e "Para iniciar bspwm:"
    echo -e "  • Con startx: ${YELLOW}startx${NC}"
    echo -e "  • Con display manager: selecciona ${YELLOW}bspwm${NC} en la sesión"
    echo ""
    echo -e "Atajos principales:"
    echo -e "  ${YELLOW}Super + Enter${NC}  = Terminal"
    echo -e "  ${YELLOW}Super + Space${NC}  = Lanzador de apps"
    echo -e "  ${YELLOW}Super + Q${NC}      = Cerrar ventana"
    echo -e "  ${YELLOW}Super + 1-9${NC}    = Cambiar escritorio"
    echo ""
    echo -e "Log guardado en: ${YELLOW}$LOG_FILE${NC}"
}

# ============================================
# MAIN
# ============================================

main() {
    # Inicializar log
    echo "Instalación de Dotfiles - $(date)" > "$LOG_FILE"
    
    # Detectar sistema
    DISTRO=$(detect_distro)
    
    if [ "$DISTRO" == "unknown" ]; then
        error "Distribución no soportada. Contacta al desarrollador."
        exit 1
    fi
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto|-a)
                AUTO_MODE=true
                shift
                ;;
            --skip-packages|-sp)
                SKIP_PACKAGES=true
                shift
                ;;
            --skip-stow|-ss)
                SKIP_STOW=true
                shift
                ;;
            --select|-s)
                SELECTIVE_INSTALL="$2"
                shift 2
                ;;
            --help|-h)
                echo "Uso: $0 [OPCIONES]"
                echo ""
                echo "Opciones:"
                echo "  --auto, -a           Modo automático sin interacción"
                echo "  --skip-packages, -sp Saltar instalación de paquetes"
                echo "  --skip-stow, -ss     Saltar aplicación de configuraciones"
                echo "  --select, -s LISTA   Instalar solo paquetes específicos (separados por coma)"
                echo "  --help, -h           Mostrar esta ayuda"
                echo ""
                echo "Ejemplos:"
                echo "  $0 --auto                    # Instalación completa automática"
                echo "  $0 --select bspwm,sxhkd,polybar  # Solo instalar estos paquetes"
                exit 0
                ;;
            *)
                error "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done
    
    # Ejecución según modo
    if [ "$AUTO_MODE" == true ]; then
        run_auto_mode
    else
        # Modo interactivo
        while true; do
            show_menu
            read -p "Selecciona una opción [1-8]: " choice
            
            case $choice in
                1)
                    run_auto_mode
                    read -p "Presiona Enter para continuar..."
                    ;;
                2)
                    install_stow
                    install_aur_helper
                    install_all_packages
                    read -p "Presiona Enter para continuar..."
                    ;;
                3)
                    install_stow
                    backup_existing_configs
                    apply_stow_configs
                    read -p "Presiona Enter para continuar..."
                    ;;
                4)
                    echo "Paquetes disponibles:"
                    ls -1 "$DOTFILES_DIR"
                    read -p "Introduce los paquetes separados por coma: " pkgs
                    SELECTIVE_INSTALL="$pkgs"
                    install_stow
                    backup_existing_configs
                    apply_stow_configs
                    read -p "Presiona Enter para continuar..."
                    ;;
                5)
                    log "Desinstalando configuraciones..."
                    cd "$DOTFILES_DIR"
                    stow -D */ 2>/dev/null || true
                    success "Configuraciones desinstaladas"
                    read -p "Presiona Enter para continuar..."
                    ;;
                6)
                    ./backup.sh 2>/dev/null || warning "Script backup.sh no encontrado"
                    read -p "Presiona Enter para continuar..."
                    ;;
                7)
                    if [ -f "$LOG_FILE" ]; then
                        less "$LOG_FILE"
                    else
                        warning "No hay log disponible"
                    fi
                    ;;
                8)
                    echo "¡Hasta luego!"
                    exit 0
                    ;;
                *)
                    error "Opción inválida"
                    ;;
            esac
        done
    fi
}

# Ejecutar
main "$@"
