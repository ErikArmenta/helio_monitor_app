#!/bin/bash

# 1. Clona Flutter versión estable (solo lo último, para no pesar)
echo "🔄 Descargando Flutter desde GitHub..."
git clone --depth 1 https://github.com/flutter/flutter.git -b stable

# 2. Toma las variables de entorno que le pasaste a Vercel y las inyecta en el build
echo "🔧 Construyendo la Web..."
./flutter/bin/flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Nota: Si usas más variables (como OpenAI), agrégalas aquí con \ al final de cada línea.