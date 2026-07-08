#!/bin/bash
echo "🔄 Descargando Flutter desde GitHub..."
git clone --depth 1 https://github.com/flutter/flutter.git -b stable

echo "⚙️  Configurando el proyecto para la web..."
./flutter/bin/flutter create . --platforms web

echo "🔧 Construyendo la Web..."
./flutter/bin/flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
