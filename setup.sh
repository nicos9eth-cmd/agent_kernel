#!/bin/bash

# 1. Définition du nom du projet
PROJECT_NAME="agent_kernel"

echo "🌍 Initialisation de l'univers $PROJECT_NAME..."

# 2. Création automatique du dossier si on est "ailleurs"
if [ "${PWD##*/}" != "$PROJECT_NAME" ]; then
    echo "📂 Création du dossier racine..."
    mkdir -p $PROJECT_NAME
    cd $PROJECT_NAME
fi

# 3. Nettoyage et structure interne
echo "🧹 Nettoyage des anciennes traces..."
sudo rm -rf rootfs alpine.tar.gz

echo "🏗️ Construction du RootFS..."
mkdir rootfs
curl -s -o alpine.tar.gz https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.4-x86_64.tar.gz
tar -xzf alpine.tar.gz -C rootfs

# 4. Configuration DNS & Python (Optimisé sans cache)
echo "🧠 Injection de l'intelligence..."
sudo cp /etc/resolv.conf rootfs/etc/resolv.conf

sudo chroot rootfs /bin/sh -c "
    apk add --no-cache python3 py3-pip &&
    pip install --no-cache-dir --upgrade pip &&
    pip install --no-cache-dir hyperliquid-python-sdk requests
"

# 5. Création d'un mini-script de test interne pour l'agent
cat <<EOF > rootfs/home/check_sdk.py
import sys
try:
    import hyperliquid
    print("✅ SDK Hyperliquid détecté et prêt dans le Kernel !")
except ImportError:
    print("❌ Erreur : SDK non trouvé.")
EOF

echo "✨ [TERMINÉ] Ton infrastructure est prête dans le dossier : $(pwd)"
echo "👉 Pour tester : sudo chroot rootfs python3 /home/check_sdk.py"

# --- SECTION VALIDATION ---
echo "🔍 Lancement de la checklist de validation..."

# 1. Test Réseau
if sudo chroot rootfs ping -c 1 google.com > /dev/null 2>&1; then
    echo "✅ Réseau : OK"
else
    echo "❌ Réseau : ÉCHEC (Vérifie ta connexion)"
fi

# 2. Test SDK Hyperliquid
if sudo chroot rootfs python3 /home/check_sdk.py | grep -q "SUCCESS"; then
    echo "✅ SDK Hyperliquid : OK"
else
    echo "❌ SDK Hyperliquid : ÉCHEC"
fi

# --- SECTION IA (Préparation) ---
echo "🤖 Installation d'Ollama (Hôte)..."
# On installe Ollama sur la machine principale pour piloter la VM
curl -fsSL https://ollama.com/install.sh | sh
