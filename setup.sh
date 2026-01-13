#!/bin/bash

# ==========================================
# 🚀 SETUP GOD MODE : AGENT KERNEL + UI
# ==========================================

PROJECT_NAME="agent_kernel"
MODEL_NAME="qwen2.5-coder:1.5b" # Modèle léger et puissant pour le code

echo "🌍 Initialisation de l'architecture $PROJECT_NAME..."

# --- 1. PRÉPARATION DE L'HÔTE (GITHUB CODESPACE) ---
echo "🛠️  Mise à jour de l'hôte..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y pciutils lshw > /dev/null 2>&1 # Utiles pour debug matériel

# --- 2. CONSTRUCTION DU KERNEL (ISOLATION) ---
# On vérifie si on est dans le bon dossier, sinon on le crée
if [ "${PWD##*/}" != "$PROJECT_NAME" ]; then
    mkdir -p $PROJECT_NAME
    cd $PROJECT_NAME
fi

echo "🧹 Nettoyage et Reconstruction du RootFS..."
sudo rm -rf rootfs alpine.tar.gz
mkdir rootfs
curl -s -o alpine.tar.gz https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.4-x86_64.tar.gz
tar -xzf alpine.tar.gz -C rootfs

# Configuration DNS & Python dans la "prison"
echo "📦 Injection des outils dans le Kernel..."
sudo cp /etc/resolv.conf rootfs/etc/resolv.conf
sudo chroot rootfs /bin/sh -c "
    apk add --no-cache python3 py3-pip > /dev/null 2>&1 &&
    pip install --no-cache-dir --upgrade pip > /dev/null 2>&1 &&
    pip install --no-cache-dir hyperliquid-python-sdk requests > /dev/null 2>&1
"

# Création du script de santé interne
cat <<EOF | sudo tee rootfs/home/health_check.py > /dev/null
import sys
try:
    import hyperliquid
    import requests
    print("✅ SYSTEME INTERNE OPÉRATIONNEL")
except ImportError as e:
    print(f"❌ ERREUR CRITIQUE : {e}")
EOF

# --- 3. INSTALLATION DU CERVEAU (OLLAMA) ---
if ! command -v ollama &> /dev/null; then
    echo "🤖 Installation d'Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh > /dev/null 2>&1
else
    echo "🤖 Ollama est déjà installé."
fi

# Démarrage du serveur Ollama en arrière-plan
echo "🧠 Démarrage du moteur neuronal..."
ollama serve > /dev/null 2>&1 &
PID_OLLAMA=$!
sleep 5 # On laisse le temps au serveur de démarrer

# Téléchargement du modèle (si absent)
echo "📥 Téléchargement du modèle $MODEL_NAME (peut prendre 1-2 min)..."
ollama pull $MODEL_NAME > /dev/null 2>&1

# --- 4. CRÉATION DE L'INTERFACE STREAMLIT ---
echo "🎨 Génération du Dashboard de contrôle..."
pip install streamlit > /dev/null 2>&1

# On crée le fichier Python de l'interface dynamiquement
cat <<EOF > dashboard.py
import streamlit as st
import subprocess
import requests
import json

st.set_page_config(layout="wide", page_title="Agent Kernel Interface")

st.title("⚡ Agent Kernel : God Mode")

# Layout: Colonne de gauche (Chat), Colonne de droite (Terminal/Action)
col1, col2 = st.columns(2)

with col1:
    st.header("💬 Dialogue avec l'Agent ($MODEL_NAME)")
    user_input = st.text_area("Votre ordre :", "Écris un script Python qui affiche le prix du Bitcoin.")
    
    if st.button("Envoyer l'ordre"):
        with st.spinner('Réflexion en cours...'):
            # Appel à l'API locale d'Ollama
            payload = {
                "model": "$MODEL_NAME",
                "prompt": f"Tu es un expert en code Python. Écris SEULEMENT le code Python pour répondre à cette demande, sans explications : {user_input}",
                "stream": False
            }
            try:
                response = requests.post("http://localhost:11434/api/generate", json=payload)
                generated_code = response.json()['response']
                st.session_state['code'] = generated_code
                st.success("Code généré !")
            except Exception as e:
                st.error(f"Erreur Ollama: {e}")

with col2:
    st.header("🖥️ Kernel (Environnement Isolé)")
    
    if 'code' in st.session_state:
        st.subheader("Code proposé par l'IA :")
        code_to_run = st.text_area("Éditeur", st.session_state['code'], height=200)
        
        # Sauvegarde dans le rootfs
        if st.button("🚀 Exécuter dans le Kernel"):
            # 1. Écrire le fichier DANS le système de fichiers isolé
            with open("rootfs/home/agent_task.py", "w") as f:
                f.write(code_to_run)
            
            # 2. Exécuter via chroot
            try:
                result = subprocess.run(
                    ["sudo", "chroot", "rootfs", "python3", "/home/agent_task.py"],
                    capture_output=True, text=True, timeout=10
                )
                st.code(result.stdout, language="bash")
                if result.stderr:
                    st.error(f"Erreur Kernel : {result.stderr}")
            except Exception as e:
                st.error(f"Erreur d'exécution : {e}")

EOF

# --- 5. CHECKLIST FINALE ---
echo "🔍 DIAGNOSTIC FINAL :"

# Test Réseau
if sudo chroot rootfs ping -c 1 google.com > /dev/null 2>&1; then
    echo "   ✅ Réseau Kernel : CONNECTÉ"
else
    echo "   ❌ Réseau Kernel : DÉCONNECTÉ"
fi

# Test Python Interne
if sudo chroot rootfs python3 /home/health_check.py | grep -q "OPÉRATIONNEL"; then
    echo "   ✅ Environnement Python : PRÊT"
else
    echo "   ❌ Environnement Python : CORROMPU"
fi

# Test Ollama
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "   ✅ Cerveau IA (Ollama) : ACTIF"
else
    echo "   ❌ Cerveau IA : INACTIF"
fi

echo ""
echo "✨ SETUP TERMINÉ AVEC SUCCÈS !"
echo "👉 Pour lancer l'interface, tape : streamlit run dashboard.py"
echo "   (GitHub Codespaces ouvrira automatiquement un nouvel onglet)"
