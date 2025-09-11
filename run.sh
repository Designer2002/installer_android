#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Установщик Привязки ПсУ ===${NC}"
echo -e "${YELLOW}Начинаем процесс установки...${NC}"

pkg install aapt2

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

# === commands inside proot-distro (Ubuntu) ===

# Re-declare helper functions inside chrooted session (to be safe)
print_step() {
    echo -e "\033[0;32m[ШАГ $1]\033[0m $2"
}
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "\033[0;32m✓ Успешно\033[0m"
    else
        echo -e "\033[0;31m✗ Ошибка!\033[0m"
        exit 1
    fi
}
is_directory_exists() {
    [ -d "$1" ]
    return $?
}
is_file_exists() {
    [ -f "$1" ]
    return $?
}

# Update and upgrade system
print_step "1" "Обновление системы..."
echo -e "\033[1;33mВыполняем: apt update && apt upgrade -y\033[0m"
apt update && apt upgrade -y
check_success

# Install required packages
print_step "2" "Установка необходимых пакетов..."
packages=("openjdk-17-jdk" "openssl" "ca-certificates" "libzbar0" "python3" "wget" "unzip" "git" "curl" "unzip")
for package in "${packages[@]}"; do
    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        echo -e "\033[0;32m✓ Пакет $package уже установлен\033[0m"
    else
        echo -e "\033[1;33mУстанавливаем пакет: $package\033[0m"
        apt install -y "$package"
        check_success
    fi
done
update-ca-certificates
apt upgrade openssl

# Create Android SDK directory
print_step "3" "Создание директории Android SDK..."
if is_directory_exists "$HOME/android-sdk/cmdline-tools"; then
    echo -e "\033[0;32m✓ Директория Android SDK уже существует\033[0m"
else
    echo -e "\033[1;33mВыполняем: mkdir -p $HOME/android-sdk/cmdline-tools\033[0m"
    mkdir -p "$HOME/android-sdk/cmdline-tools"
    check_success
fi

cd "$HOME/android-sdk/cmdline-tools" || exit 1

# Download Android command line tools
print_step "4" "Загрузка Android Command Line Tools..."
if is_file_exists "cmdline-tools.zip"; then
    echo -e "\033[0;32m✓ Файл cmdline-tools.zip уже существует\033[0m"
else
    echo -e "\033[1;33mВыполняем: wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip\033[0m"
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
    check_success
fi

# Extract and setup tools (try to be tolerant to different zip layouts)
print_step "5" "Распаковка и настройка инструментов..."
if [ -d "tools" ] || [ -d "latest" ] || [ -f "cmdline-tools.zip" ]; then
    if ! is_directory_exists "tools" && ! is_directory_exists "latest"; then
        unzip -o cmdline-tools.zip
        check_success
        # many zips create a 'cmdline-tools' folder which contains 'bin' or 'tools'
        if is_directory_exists "cmdline-tools"; then
            # keep vendor layout: put extracted folder at cmdline-tools/tools if necessary
            if is_directory_exists "cmdline-tools" && ! is_directory_exists "tools"; then
                # move inner folder to tools so path becomes cmdline-tools/tools/bin/sdkmanager
                mv cmdline-tools tools 2>/dev/null || true
            fi
        fi
    else
        echo -e "\033[0;32m✓ Инструменты уже распакованы (tools/latest есть)\033[0m"
    fi
else
    echo -e "\033[0;31m✘ Не удалось распаковать cmdline-tools.zip\033[0m"
    exit 1
fi

# Set environment variables
print_step "6" "Настройка переменных окружения..."
if grep -q "ANDROID_HOME" ~/.bashrc 2>/dev/null; then
    echo -e "\033[0;32m✓ Переменные окружения уже настроены\033[0m"
else
    echo -e "\033[1;33mВыполняем: настройка переменных окружения\033[0m"
    export ANDROID_HOME=$HOME/android-sdk
    export PATH=$ANDROID_HOME/cmdline-tools/tools/bin:$ANDROID_HOME/platform-tools:$PATH

    # Add to bashrc for persistence
    echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.bashrc
    echo 'export ANDROID_SDK_ROOT=$HOME/android-sdk' >> ~/.bashrc
    echo 'export PATH=$ANDROID_HOME/cmdline-tools/tools/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.bashrc
    check_success
fi

# reload env in this session
export ANDROID_HOME=$HOME/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/tools/bin:$ANDROID_HOME/platform-tools:$PATH

# Try to locate sdkmanager (support several layouts)
SDKMANAGER=""
if [ -x "$ANDROID_HOME/cmdline-tools/tools/bin/sdkmanager" ]; then
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/tools/bin/sdkmanager"
elif [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
elif [ -x "$ANDROID_HOME/cmdline-tools/latest/tools/bin/sdkmanager" ]; then
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/tools/bin/sdkmanager"
else
    # fallback: try to find any sdkmanager under cmdline-tools
    SDKMANAGER="$(find "$ANDROID_HOME/cmdline-tools" -type f -name sdkmanager -print -quit 2>/dev/null || true)"
fi

if [ -z "$SDKMANAGER" ]; then
    echo -e "\033[0;31m✘ sdkmanager не найден в $ANDROID_HOME/cmdline-tools\033[0m"
    echo -e "\033[1;33mПроверьте, что cmdline-tools корректно распакованы.\033[0m"
    exit 1
else
    echo -e "\033[0;32m✓ Найден sdkmanager: $SDKMANAGER\033[0m"
fi

# Install Android SDK components
print_step "7" "Установка компонентов Android SDK..."
components=("platform-tools" "build-tools;34.0.0" "platforms;android-34")
missing=()
for component in "${components[@]}"; do
    # compute expected path for this component
    expected="$ANDROID_HOME/$(echo "$component" | tr ';' '/')"
    if [ ! -e "$expected" ]; then
        missing+=("$component")
    else
        echo -e "\033[0;32m✓ Компонент $component уже установлен\033[0m"
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo -e "\033[1;33mУстанавливаем компоненты: ${missing[*]}\033[0m"
    # Use the working pattern: pipe a single "y" into sdkmanager to accept prompts during install
    echo y | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "${missing[@]}"
    check_success
else
    echo -e "\033[0;32m✓ Все требуемые компоненты уже установлены\033[0m"
fi


# Accept licenses (try automatic, otherwise ask user)
print_step "8" "Принятие лицензий..."
echo -e "\033[1;33mПробуем автоматически принять лицензии (если получится)...\033[0m"
if echo y | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses; then
    echo -e "\033[0;32m✓ Лицензии приняты автоматически\033[0m"
else
    echo -e "\033[1;33mАвтоматическое принятие лицензий не сработало.\033[0m"
    echo -e "\033[1;33mПожалуйста, выполните вручную:\033[0m"
    echo -e "\033[0;34m$SDKMANAGER --sdk_root=$ANDROID_HOME --licenses\033[0m"
    echo -e "\033[1;33mПосле принятия лицензий нажмите Enter для продолжения...\033[0m"
    read -r _
fi

# Clone the project
print_step "9" "Клонирование проекта..."
if is_directory_exists "$HOME/apk"; then
    echo -e "\033[0;32m✓ Проект уже склонирован\033[0m"
    echo -e "\033[1;33mОбновляем репозиторий...\033[0m"
    cd "$HOME/apk" || exit 1
    git pull
    check_success
else
    echo -e "\033[1;33mВыполняем: git clone https://github.com/Designer2002/apk.git\033[0m"
    cd "$HOME" || exit 1
    git clone https://github.com/Designer2002/apk.git
    check_success
fi

# Setup project directory
print_step "10" "Настройка директории проекта и переменных окружения..."
cd "$HOME/apk" || exit 1

if is_file_exists "local.properties" && grep -q "sdk.dir=$HOME/android-sdk" local.properties; then
    echo -e "\033[0;32m✓ local.properties уже настроен\033[0m"
else
    echo -e "\033[1;33mВыполняем: настройка local.properties\033[0m"
    echo "sdk.dir=$HOME/android-sdk" > local.properties
    check_success
fi

if is_file_exists "gradle.properties" && grep -q "android.aapt2.FromMavenOverride" gradle.properties; then
    echo -e "\033[0;32m✓ gradle.properties уже настроен\033[0m"
else
    echo -e "\033[1;33mВыполняем: настройка gradle.properties\033[0m"
    export AAPT2=$ANDROID_HOME/build-tools/34.0.0/aapt2
    echo "android.aapt2.FromMavenOverride=$AAPT2" >> gradle.properties
    echo "org.gradle.jvmargs=-Xmx4608m" >> gradle.properties
    check_success
fi

# Make gradlew executable
print_step "11" "Делаем gradlew исполняемым..."
if [ -x "./gradlew" ]; then
    echo -e "\033[0;32m✓ gradlew уже исполняемый\033[0m"
else
    echo -e "\033[1;33mВыполняем: chmod +x gradlew\033[0m"
    chmod +x gradlew
    check_success
fi

# Clean project
print_step "12" "Очистка проекта..."
echo -e "\033[1;33mВыполняем: ./gradlew clean\033[0m"
./gradlew clean
check_success

# Build APK
print_step "13" "Сборка APK..."
echo -e "\033[1;33mВыполняем: ./gradlew assembleDebug --no-daemon\033[0m"
echo -e "\033[1;33mЭто может занять несколько минут...\033[0m"
./gradlew assembleDebug --no-daemon
check_success


# Copy APK out of Ubuntu environment
print_step "14" "Перемещение APK в домашнюю директорию Termux..."
cp ~/apk/app/build/outputs/apk/debug/psu_binding.apk /data/data/com.termux/files/home/psu_binding.apk
check_success

EOF 
EOF

# Теперь мы снова в Termux, а не в Ubuntu
echo -e "\033[1;33mПеремещаем APK в Downloads...\033[0m"
mv ~/psu_binding.apk ~/storage/downloads/
check_success

# Final message
echo -e "\033[0;32m=== УСТАНОВКА ЗАВЕРШЕНА! ===\033[0m"
echo -e "\033[0;32mГотовый APK находится здесь:\033[0m"
echo -e "\033[0;34m~/storage/downloads/psu_binding.apk\033[0m"





echo -e "${GREEN}=== СКРИПТ ВЫПОЛНЕН В Ubuntu environment ===${NC}"
