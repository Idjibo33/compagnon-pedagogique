#!/usr/bin/env bash
# ==============================================================================
# Script de compilation reproductible de sqlite-vec pour Android (Clang NDK)
# Projet : Compagnon Pédagogique
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT_DIR}/packages/sqlite_vec/src"
JNI_LIBS_DIR="${ROOT_DIR}/android/app/src/main/jniLibs"
SQLITE_VEC_VERSION="v0.1.6"

echo "=================================================="
echo " [Compagnon Pédagogique] Build Clang NDK: sqlite-vec"
echo "=================================================="

# 1. Détection de l'Android NDK
find_ndk() {
    if [[ -n "${ANDROID_NDK_HOME:-}" && -d "${ANDROID_NDK_HOME}" ]]; then
        echo "${ANDROID_NDK_HOME}"
        return 0
    fi
    if [[ -n "${ANDROID_NDK_ROOT:-}" && -d "${ANDROID_NDK_ROOT}" ]]; then
        echo "${ANDROID_NDK_ROOT}"
        return 0
    fi

    local potential_ndk_paths=(
        "${ANDROID_HOME:-$HOME/Android/Sdk}/ndk"
        "$HOME/Android/Sdk/ndk"
        "/opt/android-sdk/ndk"
        "/opt/android-ndk"
    )

    for base in "${potential_ndk_paths[@]}"; do
        if [[ -d "$base" ]]; then
            local latest_ndk
            latest_ndk="$(find "$base" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -n 1 || true)"
            if [[ -n "$latest_ndk" && -d "$latest_ndk" ]]; then
                echo "$latest_ndk"
                return 0
            fi
        fi
    done

    return 1
}

NDK_PATH="$(find_ndk || true)"

if [[ -z "${NDK_PATH}" || ! -d "${NDK_PATH}" ]]; then
    echo "[-] Erreur : Android NDK introuvable."
    echo "    Veuillez définir ANDROID_NDK_HOME ou installer l'Android NDK via Android Studio."
    exit 1
fi

echo "[+] Android NDK détecté : ${NDK_PATH}"

# 2. Détection du système hôte pour le toolchain LLVM
HOST_TAG="linux-x86_64"
if [[ "$(uname -s)" == "Darwin" ]]; then
    HOST_TAG="darwin-x86_64"
fi

TOOLCHAIN="${NDK_PATH}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"

if [[ ! -d "${TOOLCHAIN}" ]]; then
    echo "[-] Erreur : Dossier toolchain LLVM introuvable à : ${TOOLCHAIN}"
    exit 1
fi

# 3. Vérification des sources sqlite-vec (amalgamation C)
mkdir -p "${SRC_DIR}"
SQLITE_VEC_C="${SRC_DIR}/sqlite-vec.c"
SQLITE_VEC_H="${SRC_DIR}/sqlite-vec.h"

HAS_VALID_SOURCES=false
if [[ -f "${SQLITE_VEC_C}" && -s "${SQLITE_VEC_C}" ]]; then
    # Vérifier que le fichier n'est pas une page d'erreur HTTP 404
    if ! grep -q "^Not Found" "${SQLITE_VEC_C}" && ! grep -q "404: Not Found" "${SQLITE_VEC_C}"; then
        HAS_VALID_SOURCES=true
    else
        rm -f "${SQLITE_VEC_C}" "${SQLITE_VEC_H}"
    fi
fi

if [[ "${HAS_VALID_SOURCES}" == "false" ]]; then
    echo "[*] Sources C non présentes localement dans packages/sqlite_vec/src/."
    echo "[*] Tentative de téléchargement depuis le dépôt officiel..."
    DOWNLOAD_SUCCESS=false

    # URL release sqlite-vec amalgamation (tarball)
    RELEASE_URL="https://github.com/asg017/sqlite-vec/releases/download/${SQLITE_VEC_VERSION}/sqlite-vec-${SQLITE_VEC_VERSION}-amalgamation.tar.gz"
    
    if curl -sSL -f "${RELEASE_URL}" -o "${SRC_DIR}/amalgamation.tar.gz" 2>/dev/null; then
        tar -xzf "${SRC_DIR}/amalgamation.tar.gz" -C "${SRC_DIR}" --strip-components=1 2>/dev/null || true
        rm -f "${SRC_DIR}/amalgamation.tar.gz"
        if [[ -f "${SQLITE_VEC_C}" ]]; then
            HAS_VALID_SOURCES=true
            DOWNLOAD_SUCCESS=true
        fi
    fi

    if [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; then
        echo "[i] Téléchargement indisponible (mode réseau restreint ou hors-ligne)."
    fi
fi

# 4. Configuration des cibles ABI
API_LEVEL="24"

declare -A ABIS=(
    ["arm64-v8a"]="aarch64-linux-android${API_LEVEL}-clang"
    ["armeabi-v7a"]="armv7a-linux-androideabi${API_LEVEL}-clang"
    ["x86_64"]="x86_64-linux-android${API_LEVEL}-clang"
)

# 5. Compilation ou vérification des binaires
for abi in "${!ABIS[@]}"; do
    clang_compiler="${TOOLCHAIN}/${ABIS[$abi]}"
    target_dir="${JNI_LIBS_DIR}/${abi}"
    output_so="${target_dir}/libsqlite_vec.so"

    mkdir -p "${target_dir}"

    if [[ "${HAS_VALID_SOURCES}" == "true" ]]; then
        echo "[*] Compilation pour ${abi} via ${ABIS[$abi]}..."
        if [[ ! -x "${clang_compiler}" ]]; then
            clang_compiler="${TOOLCHAIN}/clang"
        fi

        "${clang_compiler}" \
            -O3 \
            -fPIC \
            -shared \
            -std=c99 \
            -Wall \
            -Wextra \
            "${SQLITE_VEC_C}" \
            -o "${output_so}" \
            -lm

        echo "[+] Succès : ${output_so} ($(du -h "${output_so}" | cut -f1))"
    else
        if [[ -f "${output_so}" && -s "${output_so}" ]]; then
            echo "[+] Binaire précompilé valide conservé : ${output_so} ($(du -h "${output_so}" | cut -f1))"
        else
            echo "[-] Erreur critique : ${output_so} absent et sources indisponibles pour ${abi}."
            exit 1
        fi
    fi
done

echo "=================================================="
echo "[+] Validation et intégrité sqlite-vec Android : OK"
echo "=================================================="
