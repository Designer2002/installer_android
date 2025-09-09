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

# Update and upgrade system
print_step "0" "Создание системы proot-distro..."
echo -e "${YELLOW}Выполняем: pkg install proot-distro && proot-distro install ubuntu && proot-distro login ubuntu${NC}"
pkg install proot-distro && proot-distro install ubuntu && proot-distro login ubuntu
check_success

# Update and upgrade system
print_step "1" "Обновление системы..."
echo -e "${YELLOW}Выполняем: apt update && apt upgrade -y${NC}"
apt update && apt upgrade -y
check_success

# Install required packages
print_step "2" "Установка необходимых пакетов..."
echo -e "${YELLOW}Выполняем: apt install -y openjdk-17-jdk wget libstdc++6 zlib1g unzip aapt2 git${NC}"
apt install -y openjdk-17-jdk wget unzip git
check_success

# Create Android SDK directory
print_step "3" "Создание директории Android SDK..."
echo -e "${YELLOW}Выполняем: mkdir -p \$HOME/android-sdk/cmdline-tools${NC}"
mkdir -p $HOME/android-sdk/cmdline-tools
cd $HOME/android-sdk/cmdline-tools
check_success

# Download Android command line tools
print_step "4" "Загрузка Android Command Line Tools..."
echo -e "${YELLOW}Выполняем: wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip${NC}"
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
check_success

# Extract and setup tools
print_step "5" "Распаковка и настройка инструментов..."
echo -e "${YELLOW}Выполняем: unzip cmdline-tools.zip && mv cmdline-tools latest && rm cmdline-tools.zip${NC}"
unzip cmdline-tools.zip && mv cmdline-tools latest && rm cmdline-tools.zip
check_success

# Set environment variables
print_step "6" "Настройка переменных окружения..."
echo -e "${YELLOW}Выполняем: export ANDROID_HOME=\$HOME/android-sdk && export PATH=\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH${NC}"
export ANDROID_HOME=$HOME/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# Add to bashrc for persistence
echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.bashrc
echo 'export ANDROID_SDK_ROOT=$HOME/android-sdk' >> ~/.bashrc
echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.bashrc
source ~/.bashrc
check_success

# Install Android SDK components
print_step "7" "Установка компонентов Android SDK..."
echo -e "${YELLOW}Выполняем: sdkmanager --install \"platform-tools\" \"build-tools;36.0.0\" \"platforms;android-36\"${NC}"
sdkmanager --install "platform-tools" "build-tools;36.0.0" "platforms;android-36"
sdkmanager "platforms;android-34"
cp ~/android-sdk/platforms/android-34/android.jar ~/android-sdk/platforms/android-36/
check_success

# Accept licenses
print_step "8" "Принятие лицензий..."
echo -e "${YELLOW}Выполняем: sdkmanager --licenses (принимаем все лицензии)${NC}"
echo -e "${YELLOW}Нажимайте 'y' и Enter для принятия всех лицензий${NC}"
yes | sdkmanager --licenses
check_success

# Проверка наличия android.jar
print_step "8.1" "Проверка android-36/android.jar..."
if [ -f "$HOME/android-sdk/platforms/android-36/android.jar" ]; then
    echo -e "${GREEN}✔ Найден android.jar в android-36${NC}"
else
    echo -e "${RED}✘ android.jar не найден. Скачиваем вручную...${NC}"
    mkdir -p "$HOME/android-sdk/platforms/android-36"
    cd "$HOME/android-sdk/platforms/android-36" || exit 1
    curl -O https://dl.google.com/android/repository/platform-36_r01.zip
    unzip -o platform-36_r01.zip
    rm -f platform-36_r01.zip
    sdkmanager "platforms;android-34"
    cp ~/android-sdk/platforms/android-34/android.jar ~/android-sdk/platforms/android-36/
    echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.bashrc
    echo 'export ANDROID_SDK_ROOT=$HOME/android-sdk' >> ~/.bashrc
    echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.bashrc
    source ~/.bashrc
    ln -s /root/android-sdk/platforms/android-36/android.jar /root/android-sdk/platforms/android-36/android.jar.
    if [ -f "$HOME/android-sdk/platforms/android-36/android.jar" ]; then
        echo -e "${GREEN}✔ android.jar успешно установлен вручную${NC}"
    else
        echo -e "${RED}✘ Не удалось получить android.jar даже вручную${NC}"
        exit 1
    fi
fi


# Clone the project
print_step "9" "Клонирование проекта..."
echo -e "${YELLOW}Выполняем: git clone https://github.com/Designer2002/apk.git${NC}"
cd $HOME
git clone https://github.com/Designer2002/apk.git
check_success

# Setup project directory
print_step "10" "Настройка директории проекта и переменных окружения..."
echo -e "${YELLOW}Выполняем: cd ~/apk && echo 'sdk.dir=\$HOME/android-sdk' > local.properties${NC} && export AAPT2='/data/data/com.termux/files/usr/bin/aapt2' && echo 'android.aapt2.FromMavenOverride=$AAPT2_PATH' >> './gradle.properties"
cd ~/apk
export AAPT2="/data/data/com.termux/files/usr/bin/aapt2"
echo "sdk.dir=$HOME/android-sdk" > local.properties
echo "\nandroid.aapt2.FromMavenOverride=$AAPT2_PATH\norg.gradle.jvmargs=-Xmx4608m" >> "./gradle.properties"
check_success

# Make gradlew executable
print_step "11" "Делаем gradlew исполняемым..."
echo -e "${YELLOW}Выполняем: chmod +x gradlew${NC}"
chmod +x gradlew
check_success

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