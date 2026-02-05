#!/bin/bash

# ============================================
# DOTFILES BACKUP SCRIPT
# Guarda configuraciones actuales en configAut/dotfiles/
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
CONFIG_SOURCE="$HOME/.config"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BACKUP DE DOTFILES${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Origen: ${YELLOW}$CONFIG_SOURCE${NC}"
echo -e "Destino: ${YELLOW}$DOTFILES_DIR${NC}"
echo ""

# Crear directorio si no existe
mkdir -p "$DOTFILES_DIR"

# Función para backup de .config
backup_config() {
    local app=$1
    local source_path="$CONFIG_SOURCE/$app"
    local dest_path="$DOTFILES_DIR/$app/.config/$app"
    
    if [ -d "$source_path" ]; then
        echo -e "${YELLOW}→ Respaldando $app...${NC}"
        rm -rf "$dest_path"
        mkdir -p "$(dirname "$dest_path")"
        cp -r "$source_path" "$dest_path"
        
        # Permisos especiales para bspwmrc
        if [ "$app" == "bspwm" ] && [ -f "$dest_path/bspwmrc" ]; then
            chmod +x "$dest_path/bspwmrc"
            echo -e "  ${GREEN}✓${NC} Permisos ejecutables aplicados a bspwmrc"
        fi
        
        echo -e "  ${GREEN}✓${NC} $app → dotfiles/$app/.config/$app"
    else
        echo -e "${RED}✗ $app no encontrado en ~/.config/${NC}"
    fi
}

# Función para archivos en $HOME
backup_home_file() {
    local filename=$1
    local subdir=$2  # subdirectorio dentro de dotfiles (ej: zsh)
    local source_path="$HOME/$filename"
    local dest_path="$DOTFILES_DIR/$subdir"
    
    if [ -f "$source_path" ]; then
        echo -e "${YELLOW}→ Respaldando $filename...${NC}"
        mkdir -p "$dest_path"
        cp "$source_path" "$dest_path/$filename"
        echo -e "  ${GREEN}✓${NC} ~/$filename → dotfiles/$subdir/$filename"
    else
        echo -e "${RED}✗ ~/$filename no encontrado${NC}"
    fi
}

# ============================================
# BACKUP DE CONFIGURACIONES
# ============================================

echo -e "${BLUE}[1/4] Configuraciones de .config/${NC}"

# BSPWM y SXHKD (gestor de ventanas)
backup_config "bspwm"
backup_config "sxhkd"

# Barra y lanzadores
backup_config "polybar"
backup_config "rofi"

# Terminal y shell
backup_config "kitty"
backup_config "alacritty"

# Compositor y notificaciones
backup_config "picom"
backup_config "dunst"

# Editores
backup_config "nvim"
backup_config "vim"

# Otros útiles
backup_config "ranger"
backup_config "mpd"
backup_config "ncmpcpp"
backup_config "zathura"
backup_config "gtk-3.0"
backup_config "gtk-4.0"

echo ""
echo -e "${BLUE}[2/4] Archivos de configuración en ~/${NC}"

# Zsh y Powerlevel10k
backup_home_file ".zshrc" "zsh"
backup_home_file ".p10k.zsh" "zsh"
backup_home_file ".zprofile" "zsh"

# Bash
backup_home_file ".bashrc" "bash"
backup_home_file ".bash_profile" "bash"

# Git
backup_home_file ".gitconfig" "git"

# Tmux
backup_home_file ".tmux.conf" "tmux"

# X11
backup_home_file ".xinitrc" "x11"
backup_home_file ".Xresources" "x11"

echo ""
echo -e "${BLUE}[3/4] Scripts personalizados${NC}"

# Scripts de usuario
if [ -d "$HOME/.local/bin" ]; then
    echo -e "${YELLOW}→ Respaldando scripts de ~/.local/bin...${NC}"
    mkdir -p "$DOTFILES_DIR/bin/.local/bin"
    cp -r "$HOME/.local/bin/"* "$DOTFILES_DIR/bin/.local/bin/" 2>/dev/null || true
    chmod +x "$DOTFILES_DIR/bin/.local/bin/"* 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Scripts copiados"
else
    echo -e "${RED}✗ ~/.local/bin no encontrado${NC}"
fi

# Scripts de bspwm específicos
if [ -d "$CONFIG_SOURCE/bspwm/scripts" ]; then
    echo -e "${YELLOW}→ Respaldando scripts de bspwm...${NC}"
    mkdir -p "$DOTFILES_DIR/bspwm/.config/bspwm/scripts"
    cp -r "$CONFIG_SOURCE/bspwm/scripts/"* "$DOTFILES_DIR/bspwm/.config/bspwm/scripts/" 2>/dev/null || true
    chmod +x "$DOTFILES_DIR/bspwm/.config/bspwm/scripts/"* 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Scripts de bspwm copiados"
fi

echo ""
echo -e "${BLUE}[4/4] Temas y personalización${NC}"

# Wallpapers
if [ -d "$HOME/Pictures/Wallpapers" ]; then
    echo -e "${YELLOW}→ Respaldando wallpapers...${NC}"
    mkdir -p "$DOTFILES_DIR/themes/Pictures/Wallpapers"
    cp -r "$HOME/Pictures/Wallpapers/"* "$DOTFILES_DIR/themes/Pictures/Wallpapers/" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Wallpapers copiados"
fi

# Fuentes personalizadas
if [ -d "$HOME/.local/share/fonts" ]; then
    echo -e "${YELLOW}→ Respaldando fuentes...${NC}"
    mkdir -p "$DOTFILES_DIR/fonts/.local/share/fonts"
    cp -r "$HOME/.local/share/fonts/"* "$DOTFILES_DIR/fonts/.local/share/fonts/" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Fuentes copiadas"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}¡BACKUP COMPLETADO!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Ubicación: ${YELLOW}$DOTFILES_DIR${NC}"
echo ""
echo -e "Para subir a GitHub:"
echo -e "  ${YELLOW}cd $SCRIPT_DIR${NC}"
echo -e "  ${YELLOW}git init${NC}"
echo -e "  ${YELLOW}git add .${NC}"
echo -e "  ${YELLOW}git commit -m \"Backup inicial de dotfiles\"${NC}"
echo -e "  ${YELLOW}git remote add origin https://github.com/tuusuario/dotfiles.git${NC}"
echo -e "  ${YELLOW}git push -u origin main${NC}"
echo ""
echo -e "Para instalar en otra máquina:"
echo -e "  ${YELLOW}./install.sh${NC}"
