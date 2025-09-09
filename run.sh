#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Установщик Привязки ПсУ ===${NC}"
echo -e "${YELLOW}Начинаем процесс установки...${NC}"

# Function to print step messages
print_step() {
    echo -e "${GREEN}[ШАГ $1]${NC} $2"
}

# Function to check if previous command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Успешно${NC}"
    else
        echo -e "${RED}✗ Ошибка!${NC}"
        exit 1
    fi
}

# Function to check if package is installed
is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
    return $?
}

# Function to check if directory exists
is_directory_exists() {
    [ -d "$1" ]
    return $?
}

# Function to check if file exists
is_file_exists() {
    [ -f "$1" ]
    return $?
}

# Function to install package if not already installed
install_package() {
    local package=$1
    if is_package_installed "$package"; then
        echo -e "${GREEN}✓ Пакет $package уже установлен${NC}"
    else
        echo -e "${YELLOW}Устанавливаем пакет: $package${NC}"
        apt install -y "$package"
        check_success
    fi
}

# Update and upgrade system
print_step "0" "Создание системы proot-distro..."
if command -v proot-distro &>/dev/null; then
    echo -e "${GREEN}✓ proot-distro уже установлен${NC}"
else
    echo -e "${YELLOW}Выполняем: pkg install proot-distro${NC}"
    pkg install proot-distro
    check_success
fi

if is_directory_exists "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu"; then
    echo -e "${GREEN}✓ Ubuntu уже установлена в proot-distro${NC}"
else
    echo -e "${YELLOW}Выполняем: proot-distro install ubuntu${NC}"
    proot-distro install ubuntu
    check_success
fi

echo -e "${YELLOW}Вход в Ubuntu environment...${NC}"
proot-distro login ubuntu <<'EOF'

# Update and upgrade system
print_step "1" "Обновление системы..."
echo -e "${YELLOW}Выполняем: apt update && apt upgrade -y${NC}"
apt update && apt upgrade -y
check_success

# Install required packages
print_step "2" "Установка необходимых пакетов..."
packages=("openjdk-17-jdk" "wget" "unzip" "git")
for package in "${packages[@]}"; do
    install_package "$package"
done

# Create Android SDK directory
print_step "3" "Создание директории Android SDK..."
if is_directory_exists "$HOME/android-sdk/cmdline-tools"; then
    echo -e "${GREEN}✓ Директория Android SDK уже существует${NC}"
else
    echo -e "${YELLOW}Выполняем: mkdir -p $HOME/android-sdk/cmdline-tools${NC}"
    mkdir -p "$HOME/android-sdk/cmdline-tools"
    check_success
fi

cd "$HOME/android-sdk/cmdline-tools"

# Download Android command line tools
print_step "4" "Загрузка Android Command Line Tools..."
if is_file_exists "cmdline-tools.zip"; then
    echo -e "${GREEN}✓ Файл cmdline-tools.zip уже существует${NC}"
else
    echo -e "${YELLOW}Выполняем: wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip${NC}"
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
    check_success
fi

# Extract and setup tools
print_step "5" "Распаковка и настройка инструментов..."
if is_directory_exists "latest"; then
    echo -e "${GREEN}✓ Инструменты уже распакованы${NC}"
else
    echo -e "${YELLOW}Выполняем: unzip cmdline-tools.zip && mv cmdline-tools latest && rm cmdline-tools.zip${NC}"
    unzip cmdline-tools.zip && mv cmdline-tools latest && rm cmdline-tools.zip
    check_success
fi

# Set environment variables
print_step "6" "Настройка переменных окружения..."
if grep -q "ANDROID_HOME" ~/.bashrc; then
    echo -e "${GREEN}✓ Переменные окружения уже настроены${NC}"
else
    echo -e "${YELLOW}Выполняем: настройка переменных окружения${NC}"
    export ANDROID_HOME=$HOME/android-sdk
    export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
    
    # Add to bashrc for persistence
    echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.bashrc
    echo 'export ANDROID_SDK_ROOT=$HOME/android-sdk' >> ~/.bashrc
    echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.bashrc
    check_success
fi

source ~/.bashrc

# Install Android SDK components
print_step "7" "Установка компонентов Android SDK..."
components=("platform-tools" "build-tools;36.0.0" "platforms;android-36")
for component in "${components[@]}"; do
    if is_directory_exists "$ANDROID_HOME/$(echo $component | tr ';' '/')"; then
        echo -e "${GREEN}✓ Компонент $component уже установлен${NC}"
    else
        echo -e "${YELLOW}Устанавливаем компонент: $component${NC}"
        sdkmanager --install "$component"
        check_success
    fi
done

# Install android-34 platform for compatibility
if is_directory_exists "$ANDROID_HOME/platforms/android-34"; then
    echo -e "${GREEN}✓ Платформа android-34 уже установлена${NC}"
else
    echo -e "${YELLOW}Устанавливаем платформу android-34${NC}"
    sdkmanager "platforms;android-34"
    check_success
fi

# Copy android.jar from android-34 to android-36 if needed
if is_file_exists "$ANDROID_HOME/platforms/android-36/android.jar"; then
    echo -e "${GREEN}✓ android.jar уже существует в android-36${NC}"
else
    echo -e "${YELLOW}Копируем android.jar из android-34 в android-36${NC}"
    cp "$ANDROID_HOME/platforms/android-34/android.jar" "$ANDROID_HOME/platforms/android-36/"
    check_success
fi

# Accept licenses
print_step "8" "Принятие лицензий..."
echo -e "${YELLOW}Проверяем принятые лицензии...${NC}"
if [ -d "$ANDROID_HOME/licenses" ] && [ "$(ls -A $ANDROID_HOME/licenses 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Лицензии уже приняты${NC}"
else
    echo -e "${YELLOW}Принимаем лицензии...${NC}"
    echo -e "${YELLOW}Нажимайте 'y' и Enter для принятия всех лицензий${NC}"
    yes | sdkmanager --licenses
    check_success
fi

# Проверка наличия android.jar
print_step "8.1" "Проверка android-36/android.jar..."
if is_file_exists "$HOME/android-sdk/platforms/android-36/android.jar"; then
    echo -e "${GREEN}✔ Найден android.jar в android-36${NC}"
else
    echo -e "${RED}✘ android.jar не найден. Скачиваем вручную...${NC}"
    mkdir -p "$HOME/android-sdk/platforms/android-36"
    cd "$HOME/android-sdk/platforms/android-36" || exit 1
    curl -O https://dl.google.com/android/repository/platform-36_r01.zip
    unzip -o platform-36_r01.zip
    rm -f platform-36_r01.zip
    
    # Если все еще не найден, копируем из android-34
    if ! is_file_exists "$HOME/android-sdk/platforms/android-36/android.jar"; then
        sdkmanager "platforms;android-34"
        cp "$HOME/android-sdk/platforms/android-34/android.jar" "$HOME/android-sdk/platforms/android-36/"
    fi
    
    if is_file_exists "$HOME/android-sdk/platforms/android-36/android.jar"; then
        echo -e "${GREEN}✔ android.jar успешно установлен${NC}"
    else
        echo -e "${RED}✘ Не удалось получить android.jar${NC}"
        exit 1
    fi
fi

# Clone the project
print_step "9" "Клонирование проекта..."
if is_directory_exists "$HOME/apk"; then
    echo -e "${GREEN}✓ Проект уже склонирован${NC}"
    echo -e "${YELLOW}Обновляем репозиторий...${NC}"
    cd "$HOME/apk"
    git pull
    check_success
else
    echo -e "${YELLOW}Выполняем: git clone https://github.com/Designer2002/apk.git${NC}"
    cd "$HOME"
    git clone https://github.com/Designer2002/apk.git
    check_success
fi

# Setup project directory
print_step "10" "Настройка директории проекта и переменных окружения..."
cd "$HOME/apk"

if is_file_exists "local.properties" && grep -q "sdk.dir=$HOME/android-sdk" local.properties; then
    echo -e "${GREEN}✓ local.properties уже настроен${NC}"
else
    echo -e "${YELLOW}Выполняем: настройка local.properties${NC}"
    echo "sdk.dir=$HOME/android-sdk" > local.properties
    check_success
fi

if is_file_exists "gradle.properties" && grep -q "android.aapt2.FromMavenOverride" gradle.properties; then
    echo -e "${GREEN}✓ gradle.properties уже настроен${NC}"
else
    echo -e "${YELLOW}Выполняем: настройка gradle.properties${NC}"
    export AAPT2="/data/data/com.termux/files/usr/bin/aapt2"
    echo "android.aapt2.FromMavenOverride=$AAPT2" >> gradle.properties
    echo "org.gradle.jvmargs=-Xmx4608m" >> gradle.properties
    check_success
fi

# Make gradlew executable
print_step "11" "Делаем gradlew исполняемым..."
if [ -x "./gradlew" ]; then
    echo -e "${GREEN}✓ gradlew уже исполняемый${NC}"
else
    echo -e "${YELLOW}Выполняем: chmod +x gradlew${NC}"
    chmod +x gradlew
    check_success
fi

# Clean project
print_step "12" "Очистка проекта..."
echo -e "${YELLOW}Выполняем: ./gradlew clean${NC}"
./gradlew clean
check_success

# Build APK
print_step "13" "Сборка APK..."
echo -e "${YELLOW}Выполняем: ./gradlew assembleDebug --no-daemon${NC}"
echo -e "${YELLOW}Это может занять несколько минут...${NC}"
./gradlew assembleDebug --no-daemon
check_success

# Final message
echo -e "${GREEN}=== УСТАНОВКА ЗАВЕРШЕНА! ===${NC}"
echo -e "${GREEN}Готовый APK находится здесь:${NC}"
echo -e "${BLUE}~/apk/app/build/outputs/apk/debug/app-debug.apk${NC}"
echo -e ""
echo -e "${YELLOW}Чтобы скопировать APK в хранилище, выполните:${NC}"
echo -e "${BLUE}cp ~/apk/app/build/outputs/apk/debug/app-debug.apk ~/storage/shared/${NC}"

EOF

echo -e "${GREEN}=== СКРИПТ ВЫПОЛНЕН В Ubuntu environment ===${NC}"
