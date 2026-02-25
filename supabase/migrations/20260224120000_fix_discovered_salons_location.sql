-- Fix discovered_salons location assignments.
-- Problem: scraper assigns city/state based on which query was running,
-- not the actual salon location. Salons in PV are tagged as Philadelphia, etc.
-- Solution: Use PostGIS coordinates to assign nearest known city center.

BEGIN;

-- Step 1: Create temporary city centers reference
CREATE TEMP TABLE city_centers (
  city_name text NOT NULL,
  state_name text NOT NULL,
  center_point geography(Point, 4326) NOT NULL
);

INSERT INTO city_centers (city_name, state_name, center_point) VALUES
  -- Mexico
  ('Ciudad de Mexico', 'Ciudad de Mexico', ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326)::geography),
  ('Guadalajara', 'Jalisco', ST_SetSRID(ST_MakePoint(-103.3496, 20.6597), 4326)::geography),
  ('Zapopan', 'Jalisco', ST_SetSRID(ST_MakePoint(-103.3893, 20.7214), 4326)::geography),
  ('Tlaquepaque', 'Jalisco', ST_SetSRID(ST_MakePoint(-103.3139, 20.6411), 4326)::geography),
  ('Tonala', 'Jalisco', ST_SetSRID(ST_MakePoint(-103.2317, 20.6245), 4326)::geography),
  ('Puerto Vallarta', 'Jalisco', ST_SetSRID(ST_MakePoint(-105.2253, 20.6200), 4326)::geography),
  ('Bahia de Banderas', 'Nayarit', ST_SetSRID(ST_MakePoint(-105.3100, 20.7300), 4326)::geography),
  ('Tepic', 'Nayarit', ST_SetSRID(ST_MakePoint(-104.8946, 21.5044), 4326)::geography),
  ('Monterrey', 'Nuevo Leon', ST_SetSRID(ST_MakePoint(-100.3161, 25.6866), 4326)::geography),
  ('Puebla', 'Puebla', ST_SetSRID(ST_MakePoint(-98.2063, 19.0414), 4326)::geography),
  ('Tijuana', 'Baja California', ST_SetSRID(ST_MakePoint(-117.0382, 32.5149), 4326)::geography),
  ('Leon', 'Guanajuato', ST_SetSRID(ST_MakePoint(-101.6820, 21.1221), 4326)::geography),
  ('Guanajuato', 'Guanajuato', ST_SetSRID(ST_MakePoint(-101.2574, 21.0190), 4326)::geography),
  ('Ciudad Juarez', 'Chihuahua', ST_SetSRID(ST_MakePoint(-106.4245, 31.6904), 4326)::geography),
  ('Queretaro', 'Queretaro', ST_SetSRID(ST_MakePoint(-100.3899, 20.5888), 4326)::geography),
  ('Merida', 'Yucatan', ST_SetSRID(ST_MakePoint(-89.5926, 20.9674), 4326)::geography),
  ('San Luis Potosi', 'San Luis Potosi', ST_SetSRID(ST_MakePoint(-100.9855, 22.1565), 4326)::geography),
  ('Aguascalientes', 'Aguascalientes', ST_SetSRID(ST_MakePoint(-102.2916, 21.8818), 4326)::geography),
  ('Hermosillo', 'Sonora', ST_SetSRID(ST_MakePoint(-110.9559, 29.0729), 4326)::geography),
  ('Saltillo', 'Coahuila', ST_SetSRID(ST_MakePoint(-100.9924, 25.4232), 4326)::geography),
  ('Mexicali', 'Baja California', ST_SetSRID(ST_MakePoint(-115.4523, 32.6245), 4326)::geography),
  ('Culiacan', 'Sinaloa', ST_SetSRID(ST_MakePoint(-107.3940, 24.7994), 4326)::geography),
  ('Cancun', 'Quintana Roo', ST_SetSRID(ST_MakePoint(-86.8515, 21.1619), 4326)::geography),
  ('Chihuahua', 'Chihuahua', ST_SetSRID(ST_MakePoint(-106.0889, 28.6353), 4326)::geography),
  ('Morelia', 'Michoacan', ST_SetSRID(ST_MakePoint(-101.1950, 19.7060), 4326)::geography),
  ('Toluca', 'Estado de Mexico', ST_SetSRID(ST_MakePoint(-99.6557, 19.2826), 4326)::geography),
  ('Torreon', 'Coahuila', ST_SetSRID(ST_MakePoint(-103.4068, 25.5428), 4326)::geography),
  ('Veracruz', 'Veracruz', ST_SetSRID(ST_MakePoint(-96.1342, 19.1738), 4326)::geography),
  ('Reynosa', 'Tamaulipas', ST_SetSRID(ST_MakePoint(-98.2776, 26.0921), 4326)::geography),
  ('Mazatlan', 'Sinaloa', ST_SetSRID(ST_MakePoint(-106.4111, 23.2494), 4326)::geography),
  ('Playa del Carmen', 'Quintana Roo', ST_SetSRID(ST_MakePoint(-87.0739, 20.6296), 4326)::geography),
  ('Cabo San Lucas', 'Baja California Sur', ST_SetSRID(ST_MakePoint(-109.9167, 22.8905), 4326)::geography),
  ('San Jose del Cabo', 'Baja California Sur', ST_SetSRID(ST_MakePoint(-109.6982, 23.0628), 4326)::geography),
  ('La Paz', 'Baja California Sur', ST_SetSRID(ST_MakePoint(-110.3128, 24.1426), 4326)::geography),
  ('Campeche', 'Campeche', ST_SetSRID(ST_MakePoint(-90.5255, 19.8444), 4326)::geography),
  ('Tuxtla Gutierrez', 'Chiapas', ST_SetSRID(ST_MakePoint(-93.1150, 16.7528), 4326)::geography),
  ('Colima', 'Colima', ST_SetSRID(ST_MakePoint(-103.7241, 19.2452), 4326)::geography),
  ('Durango', 'Durango', ST_SetSRID(ST_MakePoint(-104.6532, 24.0277), 4326)::geography),
  ('Acapulco', 'Guerrero', ST_SetSRID(ST_MakePoint(-99.8237, 16.8531), 4326)::geography),
  ('Taxco', 'Guerrero', ST_SetSRID(ST_MakePoint(-99.6050, 18.5565), 4326)::geography),
  ('Pachuca', 'Hidalgo', ST_SetSRID(ST_MakePoint(-98.7592, 20.1011), 4326)::geography),
  ('Cuernavaca', 'Morelos', ST_SetSRID(ST_MakePoint(-99.2216, 18.9242), 4326)::geography),
  ('Oaxaca', 'Oaxaca', ST_SetSRID(ST_MakePoint(-96.7266, 17.0732), 4326)::geography),
  ('Chetumal', 'Quintana Roo', ST_SetSRID(ST_MakePoint(-88.2965, 18.5001), 4326)::geography),
  ('Tampico', 'Tamaulipas', ST_SetSRID(ST_MakePoint(-97.8611, 22.2331), 4326)::geography),
  ('Villahermosa', 'Tabasco', ST_SetSRID(ST_MakePoint(-92.9475, 17.9898), 4326)::geography),
  ('Zacatecas', 'Zacatecas', ST_SetSRID(ST_MakePoint(-102.5832, 22.7709), 4326)::geography),
  -- United States
  ('Phoenix', 'Arizona', ST_SetSRID(ST_MakePoint(-112.0740, 33.4484), 4326)::geography),
  ('San Diego', 'California', ST_SetSRID(ST_MakePoint(-117.1611, 32.7157), 4326)::geography),
  ('Jacksonville', 'Florida', ST_SetSRID(ST_MakePoint(-81.6557, 30.3322), 4326)::geography),
  ('New York', 'New York', ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)::geography),
  ('Philadelphia', 'Pennsylvania', ST_SetSRID(ST_MakePoint(-75.1652, 39.9526), 4326)::geography),
  ('Austin', 'Texas', ST_SetSRID(ST_MakePoint(-97.7431, 30.2672), 4326)::geography),
  ('Dallas', 'Texas', ST_SetSRID(ST_MakePoint(-96.7970, 32.7767), 4326)::geography),
  ('Houston', 'Texas', ST_SetSRID(ST_MakePoint(-95.3698, 29.7604), 4326)::geography),
  ('San Antonio', 'Texas', ST_SetSRID(ST_MakePoint(-98.4936, 29.4241), 4326)::geography);

-- Step 2: Find nearest city center for every salon
-- Uses LATERAL join for efficient nearest-neighbor lookup
CREATE TEMP TABLE salon_corrections AS
SELECT DISTINCT ON (ds.id)
  ds.id,
  cc.city_name AS new_city,
  cc.state_name AS new_state,
  ST_Distance(ds.location, cc.center_point) AS dist_m
FROM discovered_salons ds
CROSS JOIN city_centers cc
ORDER BY ds.id, ST_Distance(ds.location, cc.center_point);

-- Step 3: Apply corrections (only where city or state changed)
UPDATE discovered_salons ds
SET location_city = sc.new_city,
    location_state = sc.new_state,
    updated_at = now()
FROM salon_corrections sc
WHERE ds.id = sc.id
  AND (ds.location_city IS DISTINCT FROM sc.new_city
    OR ds.location_state IS DISTINCT FROM sc.new_state);

-- Step 4: Also normalize any remaining state abbreviations
-- (in case some salons are far from all city centers)
UPDATE discovered_salons
SET location_state = CASE location_state
      WHEN 'BCS' THEN 'Baja California Sur'
      WHEN 'SLP' THEN 'San Luis Potosi'
      WHEN 'CDMX' THEN 'Ciudad de Mexico'
      WHEN 'BC' THEN 'Baja California'
      WHEN 'NL' THEN 'Nuevo Leon'
      WHEN 'QR' THEN 'Quintana Roo'
      WHEN 'Edomex' THEN 'Estado de Mexico'
      WHEN 'AZ' THEN 'Arizona'
      WHEN 'CA' THEN 'California'
      WHEN 'FL' THEN 'Florida'
      WHEN 'NY' THEN 'New York'
      WHEN 'PA' THEN 'Pennsylvania'
      WHEN 'TX' THEN 'Texas'
      ELSE location_state
    END,
    updated_at = now()
WHERE location_state IN ('BCS', 'SLP', 'CDMX', 'BC', 'NL', 'QR', 'Edomex',
                         'AZ', 'CA', 'FL', 'NY', 'PA', 'TX');

-- Cleanup temp tables
DROP TABLE IF EXISTS salon_corrections;
DROP TABLE IF EXISTS city_centers;

COMMIT;
