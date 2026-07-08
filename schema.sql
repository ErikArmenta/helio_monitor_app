-- ============================================
-- Helium Recovery System - Supabase Schema
-- EA Innovation | Engineer Erik Armenta
-- Run this in Supabase SQL Editor
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Technicians
CREATE TABLE IF NOT EXISTS technicians (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  role TEXT DEFAULT 'Tecnico',
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Main readings table (matches Google Form fields + extras)
CREATE TABLE IF NOT EXISTS readings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  marca_temporal TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  technician_name TEXT NOT NULL,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE,
  turno TEXT NOT NULL CHECK (turno IN ('Manana', 'Tarde', 'Noche')),
  temperatura_celsius DOUBLE PRECISION NOT NULL,
  presion_psi DOUBLE PRECISION NOT NULL,
  evidencia_visual_url TEXT,
  temperatura_fahrenheit DOUBLE PRECISION GENERATED ALWAYS AS (temperatura_celsius * 1.8 + 32) STORED,
  vessel_pressure DOUBLE PRECISION GENERATED ALWAYS AS (presion_psi + 14.7) STORED,
  source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'esp32', 'ocr', 'form')),
  device_id TEXT,
  synced BOOLEAN DEFAULT TRUE,
  local_id TEXT UNIQUE
);

-- 3. Computed thermodynamic results
CREATE TABLE IF NOT EXISTS thermodynamic_results (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  reading_id UUID NOT NULL REFERENCES readings(id) ON DELETE CASCADE,
  compressibility_factor_z DOUBLE PRECISION NOT NULL,
  volume_factor_fv DOUBLE PRECISION NOT NULL,
  volume_helium_ft3 DOUBLE PRECISION NOT NULL,
  volume_cubic_meters DOUBLE PRECISION NOT NULL,
  diferencia_m3 DOUBLE PRECISION DEFAULT 0,
  consumo_absoluto_m3 DOUBLE PRECISION DEFAULT 0,
  computed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(reading_id)
);

-- 4. Alerts
CREATE TABLE IF NOT EXISTS alerts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  reading_id UUID REFERENCES readings(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL DEFAULT 'high_consumption',
  severity TEXT DEFAULT 'warning' CHECK (severity IN ('info', 'warning', 'critical')),
  message TEXT NOT NULL,
  consumo_value DOUBLE PRECISION,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  acknowledged BOOLEAN DEFAULT FALSE,
  acknowledged_by TEXT,
  acknowledged_at TIMESTAMPTZ
);

-- 5. AI Chat history
CREATE TABLE IF NOT EXISTS chat_history (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
  content TEXT NOT NULL,
  session_id UUID DEFAULT uuid_generate_v4(),
  metadata JSONB DEFAULT '{}'::JSONB
);

-- 6. ESP32 devices registry
CREATE TABLE IF NOT EXISTS esp32_devices (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_name TEXT NOT NULL UNIQUE,
  mac_address TEXT,
  board_type TEXT DEFAULT 'ESP32',
  firmware_version TEXT,
  sensors JSONB DEFAULT '[]'::JSONB,
  last_seen TIMESTAMPTZ,
  status TEXT DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'error')),
  config JSONB DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. OCR scan log
CREATE TABLE IF NOT EXISTS ocr_scans (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  image_url TEXT,
  raw_extracted_text TEXT,
  extracted_temperature DOUBLE PRECISION,
  extracted_pressure DOUBLE PRECISION,
  confidence DOUBLE PRECISION,
  reading_id UUID REFERENCES readings(id),
  validated BOOLEAN DEFAULT FALSE
);

-- 8. Sync queue (offline-first)
CREATE TABLE IF NOT EXISTS sync_queue (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('insert', 'update', 'delete')),
  record_data JSONB NOT NULL,
  synced BOOLEAN DEFAULT FALSE,
  synced_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INT DEFAULT 0
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_readings_marca_temporal ON readings(marca_temporal DESC);
CREATE INDEX IF NOT EXISTS idx_readings_technician ON readings(technician_name);
CREATE INDEX IF NOT EXISTS idx_readings_source ON readings(source);
CREATE INDEX IF NOT EXISTS idx_readings_synced ON readings(synced) WHERE synced = FALSE;
CREATE INDEX IF NOT EXISTS idx_thermo_reading ON thermodynamic_results(reading_id);
CREATE INDEX IF NOT EXISTS idx_alerts_reading ON alerts(reading_id);
CREATE INDEX IF NOT EXISTS idx_alerts_pending ON alerts(acknowledged) WHERE acknowledged = FALSE;
CREATE INDEX IF NOT EXISTS idx_chat_session ON chat_history(session_id);
CREATE INDEX IF NOT EXISTS idx_sync_pending ON sync_queue(synced) WHERE synced = FALSE;

-- Row Level Security
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE thermodynamic_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE esp32_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE ocr_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE technicians ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_all" ON readings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON thermodynamic_results FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON alerts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON chat_history FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON esp32_devices FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON ocr_scans FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON technicians FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all" ON sync_queue FOR ALL USING (true) WITH CHECK (true);

-- Auto-compute thermodynamics on insert/update
CREATE OR REPLACE FUNCTION compute_thermodynamics()
RETURNS TRIGGER AS $$
DECLARE
  base_volume CONSTANT DOUBLE PRECISION := 450.00;
  temp_f DOUBLE PRECISION;
  v_pressure DOUBLE PRECISION;
  t_term DOUBLE PRECISION;
  part1 DOUBLE PRECISION;
  z_factor DOUBLE PRECISION;
  f_temp DOUBLE PRECISION;
  f_pres DOUBLE PRECISION;
  f_comp DOUBLE PRECISION;
  f_exp_metal DOUBLE PRECISION;
  f_pres_efect DOUBLE PRECISION;
  fv DOUBLE PRECISION;
  vol_ft3 DOUBLE PRECISION;
  vol_m3 DOUBLE PRECISION;
  prev_vol DOUBLE PRECISION;
  diff_m3 DOUBLE PRECISION;
BEGIN
  temp_f := NEW.temperatura_celsius * 1.8 + 32;
  v_pressure := NEW.presion_psi + 14.7;
  t_term := 459.7 + temp_f;

  part1 := 0.000102297 - (0.000000192998 * t_term) + (0.00000000011836 * (t_term * t_term));
  z_factor := 1 + (part1 * v_pressure) - (0.0000000002217 * (v_pressure * v_pressure));

  f_temp := 529.7 / (temp_f + 459.7);
  f_pres := v_pressure / 14.7;
  f_comp := 1.00049 / z_factor;
  f_exp_metal := 1 + (0.0000189 * (temp_f - 70));
  f_pres_efect := 1 + (0.00000074 * v_pressure);
  fv := f_temp * f_pres * f_comp * f_exp_metal * f_pres_efect;

  vol_ft3 := base_volume * fv;
  vol_m3 := vol_ft3 / 35.315;

  SELECT volume_cubic_meters INTO prev_vol
  FROM thermodynamic_results tr
  JOIN readings r ON tr.reading_id = r.id
  WHERE r.marca_temporal < NEW.marca_temporal
  ORDER BY r.marca_temporal DESC
  LIMIT 1;

  diff_m3 := COALESCE(vol_m3 - prev_vol, 0);

  INSERT INTO thermodynamic_results (
    reading_id, compressibility_factor_z, volume_factor_fv,
    volume_helium_ft3, volume_cubic_meters, diferencia_m3, consumo_absoluto_m3
  ) VALUES (
    NEW.id, z_factor, fv, vol_ft3, vol_m3, diff_m3, ABS(diff_m3)
  )
  ON CONFLICT (reading_id) DO UPDATE SET
    compressibility_factor_z = EXCLUDED.compressibility_factor_z,
    volume_factor_fv = EXCLUDED.volume_factor_fv,
    volume_helium_ft3 = EXCLUDED.volume_helium_ft3,
    volume_cubic_meters = EXCLUDED.volume_cubic_meters,
    diferencia_m3 = EXCLUDED.diferencia_m3,
    consumo_absoluto_m3 = EXCLUDED.consumo_absoluto_m3,
    computed_at = NOW();

  IF ABS(diff_m3) > 5 THEN
    INSERT INTO alerts (reading_id, alert_type, severity, message, consumo_value)
    VALUES (
      NEW.id, 'high_consumption', 'critical',
      FORMAT('Consumo detectado: %.2f M3 | Presion: %.1f PSIA | Z: %.6f',
             ABS(diff_m3), v_pressure, z_factor),
      ABS(diff_m3)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_compute_thermodynamics
AFTER INSERT OR UPDATE ON readings
FOR EACH ROW
EXECUTE FUNCTION compute_thermodynamics();

-- Dashboard view (joins readings + thermodynamics)
CREATE OR REPLACE VIEW v_readings_full AS
SELECT
  r.id,
  r.marca_temporal,
  r.technician_name,
  r.fecha,
  r.turno,
  r.temperatura_celsius,
  r.presion_psi,
  r.temperatura_fahrenheit,
  r.vessel_pressure,
  r.evidencia_visual_url,
  r.source,
  r.device_id,
  COALESCE(t.compressibility_factor_z, 0) as compressibility_factor_z,
  COALESCE(t.volume_factor_fv, 0) as volume_factor_fv,
  COALESCE(t.volume_helium_ft3, 0) as volume_helium_ft3,
  COALESCE(t.volume_cubic_meters, 0) as volume_cubic_meters,
  COALESCE(t.diferencia_m3, 0) as diferencia_m3,
  COALESCE(t.consumo_absoluto_m3, 0) as consumo_absoluto_m3
FROM readings r
LEFT JOIN thermodynamic_results t ON t.reading_id = r.id
ORDER BY r.marca_temporal DESC;

-- Insert default technician
INSERT INTO technicians (name, role) VALUES ('Erik Armenta', 'Master Engineer')
ON CONFLICT (name) DO NOTHING;
