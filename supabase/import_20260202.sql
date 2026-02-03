-- BeautyCita discovered_salons import
-- Generated: 2026-02-02T00:04:38.910296
-- Records: 295
-- Usage: psql -U postgres -d postgres -f this_file.sql

BEGIN;

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428af9085af4afd:0x7fa9ff03e4e4da2', 'CARRETO MARTINEZ Salón de Belleza y Barberia', '+523331601838', '+523331601838', '
Av Adolfo López Mateos Nte 991 COL, Italia Providencia, 44648 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.691972, -103.3761118,
  'https://lh3.googleusercontent.com/p/AF1QipMR5eFHb9AwzMbiyTdrVk8L1LC5H3vxSJiZy0Dl=w408-h544-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b3d11ab1fdcf:0xb473c78c99db33cd', 'Coco Sala de Belleza', '+523336437214', '+523336437214', '
C. Valentín Gómez Farías 2490, San Andrés, 44810 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6610221, -103.3045523,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=tnCqablBp1wYsBXWNW07eQ&cb_client=search.gws-prod.gps&w=408&h=240&yaw=176.08716&pitch=0&thumbfov=100', 4.7, NULL, 'Comercio',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b2353d89f025:0x9cafcaeec6b14f3d', 'DaMá Salón de Belleza Integral', '+523314646030', '+523314646030', '
Av Río Nilo 2226, Prados del Nilo, 44840 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6468215, -103.3139252,
  'https://lh3.googleusercontent.com/p/AF1QipPAPh3xuS7et3ZzVB6Y7PmNXKG7PY9kSvMu65nE=w408-h559-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/damasalondebellezaintegral', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ae463d620953:0x8cebbe7197352e56', 'Feines Haar Salón De Belleza', '+523336406134', '+523336406134', '
Av Terranova 1430, Providencia 4a. Secc, 44639 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6968524, -103.3861553,
  'https://lh3.googleusercontent.com/p/AF1QipMygiVNgjvsO42uQEUIcyrNW1IQNLuV-2TIATlZ=w426-h240-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b38d9a7e300f:0x7dcd6eea79acbe5b', 'Frank Solis • Salón de belleza y estética', '+523334073776', '+523334073776', '
C. Colonos 160, Lomas del Tapatío, 45588 San Pedro Tlaquepaque, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6086272, -103.3149483,
  'https://lh3.googleusercontent.com/p/AF1QipNI2Y48EQKaNgL-y-ahzzpXtff20_0cj9ep1tkT=w408-h544-k-no', 4.2, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://m.facebook.com/muafranksolis/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b1c446e9b7d7:0x4331a268925ca8cb', 'Gerardo Cárdenas - Salón de Belleza', '+523314688353', '+523314688353', '
C. P.º de los Filósofos 1359, Colinas de La Normal, 44270 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6971641, -103.3430729,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwequBCNQTefWIkfZ0Khu_Nqp4oEC2eT1CIZnz_xQt21AXelxvSYorwV6ro1KCC6A9yHNBBpM7TpdWPo5_AK5u3GMeV209z-6kjOQXSfzWZjcigld8RIQi0I9SyIGnk0JonNwZfUEQg=w408-h407-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/gerardocardenasestilista/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ac34450ca577:0xdf03856b2450ed8f', 'L''occoco Obsidiana', '+523338550127', '+523338550127', '
Av. Obsidiana 2921, Victoria, 45060 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6445973, -103.4001371,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepRdLw0oufaXZGtxahWG0H0f_BxI26P9CWxVQJCPbBuDEBPUa6wUCawgnlsffz5ExpGZZO75HSrul9FSQ9Hj8WWUO4i3aaIterNQuczbP9FNVaCDXteqR52Rtr4ob2z2f6ZiFNy=w408-h433-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.loccoco.com/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428afb19975b40f:0xa6ab827127b5b6c3', 'LORSS - Salón de Belleza', '+523318535445', '+523318535445', '
Av. Manuel Acuña 1895-Local 5, Ladrón de Guevara, Ladron De Guevara, 44600 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6842225, -103.3759751,
  'https://lh3.googleusercontent.com/p/AF1QipMUOvj_h8t-EDEqA2VZFUOQiZXo_8UfdbjRlqGz=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428adde97b8c849:0x15d22c15ce639094', 'Loccoco Beauty I Arboledas', '+523336711198', '+523336711198', '
Av Paseo de la Arboleda 1130-local E, Rinconada del Bosque, 44530 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6576961, -103.3860775,
  'https://lh3.googleusercontent.com/p/AF1QipOOQieMRJkDL_WNcAdSel1wUde-IdIgSlYgJrmp=w408-h544-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.loccoco.com/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ae7d690fd82d:0x20f833a159b06fac', 'Loccoco Beauty | Chapalita', '+523331211825', '+523331211825', '
Av San Ignacio 93-Local 10 C, Jardín de San Ignacio, 45040 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.667349, -103.4048993,
  'https://lh3.googleusercontent.com/p/AF1QipPYPtlO71tseX_D_O5IlRvATHOY5gns-An9q711=w425-h240-k-no', 4.1, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.loccoco.com/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428add25ac6a8df:0x7d593568ab2a42f', 'Loccoco Beauty | Plaza Del Sol', '+523326165332', '+523326165332', '
Av. Adolfo López Mateos Sur 2375-Local 15B, Cd del Sol, 45055 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6524042, -103.4014461,
  'https://lh3.googleusercontent.com/p/AF1QipM_MuzWXPgZFdFIJP8FgWe53kCGdTkU0ZIKDfZv=w408-h297-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://amwebsites.my.canva.site/loccocoplazadelsol', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428adbbbe3b1037:0x8e1cbe4458c5b5f8', 'Mikaela Haircare - Salón de Belleza', '+523312516784', '+523312516784', '
C. Isla Socorro 2917, Villa Guerrero, 44987 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6315112, -103.3891727,
  'https://lh3.googleusercontent.com/p/AF1QipN5-P5IrKfubQsjf0brTSoMk_wGAL7_RimWJFqq=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ae738716f8f9:0x646b8e04e649713b', 'Minerva Maciel Salón de Belleza', '+523336473197', '+523336473197', '
Av Inglaterra 2709, Jardines del Bosque, 44520 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6687033, -103.3851862,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweop6XuWUCR6VBht8SpZNwGQY5XpPYX-ICwMujo-Otlnd42GO2iCCqSJEBMEMVc4EPLO82eI5oLs1kl-gBQnqdrnq3JDcsNEEk2IFqnhwyREQrZAWz5fsbanu8k0TdrectrI_1EW=w408-h432-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b209a50c8e87:0x3bf45cf17acbca40', 'SOY Salón de Belleza', '+523312570594', '+523312570594', '
C. El Campanario 2524, El Campanario, 45234 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.5939591, -103.4368872,
  'https://lh3.googleusercontent.com/p/AF1QipPgRs7c_EDmHl_dQKPZWoJ2EuNbG2dv7qPZHXgT=w408-h544-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.instagram.com/soysalon_official/?hl=en', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b0e23fd102c1:0xc480d79a4232a74', 'Salon De Belleza Unisex.', '+523334616268', '+523334616268', '
Av. Belisario Domínguez 3996, Huentitán El Alto, 44390 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.7179145, -103.296506,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=YHUkeJneWXgciledTRYe4w&cb_client=search.gws-prod.gps&w=408&h=240&yaw=150.7847&pitch=0&thumbfov=100', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ad9828e0c729:0x51e76cdf3560d31', 'Salón De Belleza Beyou', '+523334014424', '+523334014424', '
Av. Isla Raza 2350, Jardines de San José, 44950 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6343628, -103.3889225,
  'https://lh3.googleusercontent.com/p/AF1QipNrmG4Oowdr9ZoPat7JoGs_kQwBxDMcqaFAIfAL=w408-h408-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x86a28e98ea321735:0x29bcc2e320da4d04', 'Salón De Belleza Gaby y Jenny', '+523338170529', '+523338170529', '
Av Adolfo López Mateos Nte 1038, Italia Providencia, 44630 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6924185, -103.374909,
  'https://lh3.googleusercontent.com/p/AF1QipPtyAYMi7ArPCgSApYQW_iafekPD4moEP_2Q_km=w408-h523-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b5201d9e99fd:0xfc7b6ebee2def1f2', 'Salón de Belleza & Makeup Olivia Argueta', '+523311753934', '+523311753934', '
Sta. María 525, La Providencia, 45400 Tonalá, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6095545, -103.2435329,
  'https://lh3.googleusercontent.com/p/AF1QipPViJ_wRqkMiZOuMJZR3MyoUpdcfyrjAt0rHAST=w408-h408-k-no', 4.5, NULL, 'Centro de estética',
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b286727028e5:0x97c5f2a4c42876a9', 'Salón de Belleza Cony Martínez', '+523321581764', '+523321581764', '
Nicolás Enríquez 4181, Miravalle, 44990 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6137463, -103.3488689,
  'https://lh3.googleusercontent.com/p/AF1QipM0Xvb2K6m749mAokDkHkU2LI3a0c4SQUVo4MpH=w408-h725-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428af11452c329f:0x9ba9258a7d210ba3', 'Salón de Belleza Hair Zone / Ellos & Ellas', '+523331606969', '+523331606969', '
Av. Inglaterra 6765-Local 3, Villas de Asis, Plaza de Asis, 45017 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.691745, -103.4416075,
  'https://lh3.googleusercontent.com/p/AF1QipMUuf2rywmSPgMQaaxraMNZ1aWWsy5idkyBpZZp=w426-h240-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428add23404bbfb:0x32aa013511a52ab6', 'Salón de Belleza Herendira', '+523331226011', '+523331226011', '
Av Plaza del Sol 58, Rinconada del Sol, 45055 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6523852, -103.4002743,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqZeJV2_Ie0OOcDp3tQSp9_1RyC8NcCvivHNbVIJrgJz7FC4lFNSo-UF-FMm7fk8RW0zidGtv0rg13SXUXK50VI3_Ar5h9StdrljIswpRj5IAskvLUoCNBb35jJXKkKQyP7qJQ=w408-h544-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ad737bf90ecb:0xac88d45b60d47a73', 'Salón de Belleza Isela Romero', '+523313508688', '+523313508688', '
Av 8 de Julio 3554-D, López Portillo, 44960 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6239262, -103.3713776,
  'https://lh3.googleusercontent.com/p/AF1QipPEAI3blqHoOl19-xwC5ki_G9xYuiefTzpCd-hq=w960-h240-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/Isela-Romero-Sal%C3%B3n-de-belleza-104440294741876', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ace2f07aabf3:0x191f3dd25abfeaf3', 'Salón de Belleza Jazmin', '+523311761493', '+523311761493', '
Parota 495, Haciendas de San José, 45609 San Pedro Tlaquepaque, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6002912, -103.4070737,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwep4B8Xfjivq0736rmQchgr5MWhIXF2H7mZmtz4XQKs1Muxs2eq4YX_5l3GU39QIxz1o9kyZfjBcBJA-VNf2dPfAQcI70An3StSY2FZoxrRJ0F1tjlleMnvbD5dtwOKfPo_3qpPUHNuXqL4=w408-h526-k-no', 4.2, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.instagram.com/_beautysalon_jaz?igsh=MTk4bzN3eHo2eHByMA%3D%3D&utm_source=qr', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428adee78318b5b:0x11e89ee69b79ece1', 'Salón de Belleza Lili', '+523339557037', '+523339557037', '
C. Isla de Palos 1597, Colón, 44920 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.645383, -103.373131,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqVX5I2PrWT3Ib2UKuZXnS4E1V3jHD56vHN8nL9zE6giLmCZhyioCYiBNpe7sLaJ1dcK85E9Ig3NtO8apvYDi1-XU4R2DoUlhEbMYEvhO_nyAlWLhDBuSUANzNkdLXfduPlwe4o=w408-h306-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ad003605356f:0x745537542dbef617', 'Salón de Belleza Lolita', '+523310844099', '+523310844099', '
Vasco de Gama 2797, Colón Industrial, 44930 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6389104, -103.3749472,
  'https://lh3.googleusercontent.com/p/AF1QipODtkMZHNgjs4jcLfm25uonQzCOdBDJ-7TYJelR=w426-h240-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428af5045d2dba9:0xb32a80930412c85e', 'Salón de Belleza Pilar Castellón', '+523310833450', '+523310833450', '
C. José Clemente Orozco 394, Santa Teresita, 44600 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.682862, -103.365996,
  'https://lh3.googleusercontent.com/p/AF1QipOhDs7eIhZkPCq8nVEXIWaV7dXYfkt7AvyIqCzm=w427-h240-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/pillycastellon1206/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428aeea37bccdf5:0xdb8b62ded3f78319', 'Salón de belleza AraVe', '+523317374080', '+523317374080', '
Melville 5862, Lomas Universidad, 45016 Zapopan, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6866148, -103.4318226,
  'https://lh3.googleusercontent.com/p/AF1QipNWy0frk14144JxoQUcXo92AoUppa6J6210vs6b=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://araveestilistas.online/', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ad19b6d26a59:0x3e89d0cb7c6863f', 'Salón de belleza Carolina ozuna', '+523322244637', '+523322244637', '
C. Roberto J. Cordero 1600, López Portillo, 44960 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6242019, -103.3713112,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=bA5LU2NcB7T2HXkINZglRQ&cb_client=search.gws-prod.gps&w=408&h=240&yaw=36.73934&pitch=0&thumbfov=100', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b0347192b1d1:0x908f4f8a5535225b', 'Salón de belleza LS Lupita Suárez', '+523331272793', '+523331272793', '
Av. Experiencia 3324, Santa Elena de La Cruz, 44230 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.7168697, -103.3407725,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer1S9NPa7su6jrJOoeSgbf285jrN7sFaVj4ZFOOsVaxNEyVn2YtQhPhj3nQzO9SnFzxjmXTRHCLbeUZti54hcME9nQc1kovaYw-R5u9FrpVMfwAaBOKW6mN2U-LEBo7DmqGQcPq4g0aAC89=w408-h662-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://fb.me/LSalondebelleza', NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428ae1c30d201f5:0x10a25a540aa24821', 'Salón de belleza Orquídea Negra', '+523313827744', '+523313827744', '
C. Nicolás Romero 303, Santa Teresita, 44200 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6812968, -103.3622519,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepJg-e68YeEn2kmTwpmdNR0r98GDSlVPCCf_JmOL1h7NQ_2i-ZXvYdTz0T-ZVacZO04o1HwgNAB17k-qs1CA1Y7_AlVyq2XKrfp38I1dDn2dIqx2vE4HkqIbEdQry8oI_hWrijmBQ=w408-h725-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8428b39b6dbfe58f:0xa4b10d9f0d59039a', 'Tonsoria Salón de Belleza', '+523316042031', '+523316042031', '
Calz. Revolución 2286-Local 9B, La Paz, 44860 Guadalajara, Jal.',
  'Guadalajara', 'Jalisco', 'MX', 20.6496217, -103.3096296,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoh-vsVzUfphAfidYpiGgL9-qFtUxfKXBe8Qxca9rPmOgqEnQAM9Of4UDE60r95rN1xgECTJMw9vs27Wo9vAAGzt67pSDFVjvXN45CAdB7gWnAES-_xPnbJs3WRX5RefjGnJZuu=w408-h510-k-no', 4.4, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T20:00:26.232961+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fb6a4b95e51:0x7cf0358551a1e77c', '""Estética Unisex Mar""', '+523224060138', '+523224060138', '
Av. Víctor Iturbe 982-A, Col San Miguel, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.663884, -105.196489,
  'https://lh3.googleusercontent.com/p/AF1QipMKjJvqL43hA-XmWDUsP9_L1eOEgCKhXONWRsYX=w426-h240-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214579ea7d948b:0xdd83284fbf5bf99c', '''Classy'' Nail Bar', '+523222934223', '+523222934223', '
Av Fluvial Vallarta 260, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6427789, -105.2299269,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepNpM6RL79UM_esvEh6so6TBkY4Tqttw2iLZsL9h6kP0EMwEzy3RLz6ypA4PUqk0y0X8pCZooeczXrV_j4xTrrmegKWao-k6Ay7cGU144XyHrJgYQp50hVGbPleb0KQBDUA9R87=w408-h544-k-no', 4.4, NULL, 'Centro de estética',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454cdbb95779:0xc9232800bafcf7ce', 'Acqua Spa for Men', '+523222626707', '+523222626707', '
C. Constitución 450, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6012831, -105.2346296,
  'https://lh3.googleusercontent.com/p/AF1QipPoR3BdSV_3Tq-DjBNTdcLUXAcu01y71DVLHGgU=w408-h612-k-no', 4.8, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'http://www.acquaspapv.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147a591ed1227:0xe10058d204b07f3a', 'Adora Beauty', '+523221481987', '+523221481987', '
Blvd. Nuevo Vallarta 1000-Local 4B, Puertarena, 63735 Nuevo Vallarta, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7099526, -105.2922936,
  'https://lh3.googleusercontent.com/p/AF1QipOqVKCY516bnxdr5nnReIuxvX91JlOB99rZhSk-=w408-h272-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://adorabeautysalon.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fc384ff0c41:0x1ee76d675602d49b', 'Adriano Microblading', '+523221285103', '+523221285103', '
Cenzontle 269, Aralias II, Los Sauces, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6419466, -105.2170747,
  'https://lh3.googleusercontent.com/p/AF1QipNi7xvqteE6Fw4oAZfDcQ3j68AmJardXmteSe8j=w408-h510-k-no', 4.4, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f001e710aed:0x2e2b687b6fe6b006', 'Albert barber’s', '+523221047682', '+523221047682', '
Alameda, Coapinole, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6509365, -105.2037662,
  'https://lh3.googleusercontent.com/p/AF1QipMC4Ovm2qc7bjXqja8BHC2QtdLHIynOR4oN3pam=w408-h544-k-no', 5.0, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145bee77f4efd:0x56aa2ffbf61bbcc', 'Ally Nails', '+523221669814', '+523221669814', '
Universo 2003 A-Departamento 22, La Aurora, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6554333, -105.2358497,
  'https://lh3.googleusercontent.com/p/AF1QipOC5XrOF_d98RAgUz4XbPE0i4_ZXWne2wV6ShII=w408-h408-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454559a0ff91:0x889c2d3536f96a88', 'Almendras Garden Spa & Beauty Salón', '+523227797054', '+523227797054', '
C. Juárez 778, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6124014, -105.2324739,
  'https://lh3.googleusercontent.com/p/AF1QipN_OhKcRqig5UX12dYQosUu6Y0rQjuPj_WkWB1F=w408-h342-k-no', 4.9, NULL, 'Spa de día',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b1bbc992bb:0x8c4fe119ce325fbe', 'Anastasia Nails', '+523222100266', '+523222100266', '
Blvd. Francisco Medina Ascencio 1939, Zona Hotelera, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6322011, -105.229514,
  'https://lh3.googleusercontent.com/p/AF1QipMzgq0GtGsqJMS_PMExESEh9kHvYIDMdScb3aBi=w408-h544-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://anastasianailspv.as.me/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421470d3653a551:0xbfb982ca8c3a4434', 'Angélica Ayón Hair Studio', '+523221388886', '+523221388886', '
Av. los Robles 65, 63735 Las Jarretaderas, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7081712, -105.2712298,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerG8XMptbyMHHvZXyvUqi74yb4xDx9q42rxjPz2yOd-tZ0JITbvQmudEGRBOndLH96Rd9aCEDm8AdXosu-qGpf0EIDtoJqjrtp_bBBgT6zzTTS4D4MMDajc3NF2WiAK10aZyIe5=w408-h510-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/angelicaayonhairstudio', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x6eecc109f3c0407b:0x13c10b724a4bae29', 'Antir Salon', '+523223222077', '+523223222077', '
Francia 415, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6380691, -105.2271276,
  'https://lh3.googleusercontent.com/p/AF1QipMFPHQDLLHHydpRQH24pd80O4MFc9go8TVLjxf3=w408-h306-k-no', 4.9, NULL, 'Peluquería',
  '{cabello}', NULL, 'http://antirsalon.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c7cc27831:0xb385cd6299e13cfa', 'Ara Salón de Belleza', '+523222220966', '+523222220966', '
Lázaro Cárdenas 230-Int. 4, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6033585, -105.2364247,
  '//lh3.googleusercontent.com/skgM0RtJfXCtFt-0BzDv5PhIZLP5fGAghTMitW-1ybr3jzdw25Dm6djMil9Vujca=w408-h726-k-no', 4.5, NULL, 'Salón de manicura y pedicura',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145dbcfc7ac8f:0xd927bc5aa951b32', 'Arama spa', '+523222213895', '+523222213895', '
Av Paseo de la Marina local #18, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6625566, -105.2522642,
  'https://lh3.googleusercontent.com/p/AF1QipP7Ll8hlhWrGsZfWkIV_yPwARyqL_XCnL6TwMgd=w408-h544-k-no', 5.0, NULL, 'Spa de día',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214579c316b26f:0x6477d4976b1ebace', 'Artepil Spa (Fluvial Vallarta)', '+523222242608', '+523222242608', '
Avenida Fluvial Vallarta, Plaza San Marino 260, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.643044, -105.2303379,
  'https://lh3.googleusercontent.com/p/AF1QipMe7ZXLjWC0mgiCNZ_JXV9Tn2zYjxvVJlu5UhQD=w408-h259-k-no', 4.8, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'http://artepil.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145c6e43c2f2d:0xf4770b011a9737d8', 'Artepil Spa (Marina Vallarta)', '+523221356976', '+523221356976', '
Blvd. Francisco Medina Ascencio, 5 Interior Plaza Neptuno KM 7, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6673817, -105.2485988,
  'https://lh3.googleusercontent.com/p/AF1QipOJwqzL5QCjvzc-X2Q8YPp2MHp-BUuix9zTwtC0=w408-h300-k-no', 4.8, NULL, 'Spa de día',
  '{cuerpo_spa}', NULL, 'http://artepil.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454cf65eb88d:0xee59d7ea25f467dd', 'Artepil Spa (Zona Romántica)', '+523221829496', '+523221829496', '
Venustiano Carranza 290, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6030207, -105.2350948,
  'https://lh3.googleusercontent.com/p/AF1QipNPExAUfiU1qqIv7LK0uzV5Pwvpyx2pABANleoL=w427-h240-k-no', 4.6, NULL, 'Spa de día',
  '{cuerpo_spa}', NULL, 'http://artepil.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f65ec763e8b:0xab912bdca46b58df', 'Artesanos de la Barbería', '+523222886213', '+523222886213', '
C. Exiquio Corona 562, La Floresta, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6662045, -105.2157898,
  'https://lh3.googleusercontent.com/p/AF1QipNN5PEE1qrRqXhXiyaslRDlH9pNMoLbbl5k4VC8=w426-h240-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214565d9e54859:0x56904a961a692ece', 'BAHIA STUDIOS PV', '+523222807335', '+523222807335', '
C. Politécnico Nacional 216, Educación, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6611811, -105.2371139,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwernk7cCNxvjO1X1pVWOd1gxOZj1vNU13A-paWSnqTSMtb4tOxqht5Oy4zO_ZDQZH83uW7WSPGq_huNiauj-s7Tt6RRsoOd3HvEytDLVfrgNRn84gfjFQ6jTGje-fgQhAqlG9dEdlBsD5HD7=w408-h544-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, 'https://instagram.com/puertobarberpv?igshid=ZDdkNTZiNTM=', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452b271ffa75:0x9ccf8180c158e1d5', 'BARBA Y BARBA', '+523222750917', '+523222750917', '
5 de Febrero 261, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6051924, -105.2361891,
  'https://lh3.googleusercontent.com/p/AF1QipMxWxEMO9Uuu_RJFBcbzUKXSSQGG7_OgAfeDHPD=w408-h435-k-no', 5.0, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214597a7c60683:0x7bcefe8668b6fe68', 'BARBA Y BARBA', '+523222763990', '+523222763990', '
C. Fco. I. Madero 336, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6042468, -105.2344196,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoVXEMBjl9SvQQkv4abJsCusiPM-rLoMmfrL9NXul9x5mJwiO4NZsfSXkoUq1rXBYRpId5shF8GKan6U0svFGtakrbBOwSQtp5mGamvc341WYL95INDAOvw59qy69xGlYZqlLtg=w408-h544-k-no', 4.6, NULL, 'Barbería',
  '{cabello}', NULL, 'https://www.facebook.com/barbaybarbapv', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455f337e0bf3:0x8c0ef93ec5809d22', 'BARBEROS - PLAZA CARACOL', '+523221144632', '+523221144632', '
Plaza Caracol, Av. Francisco Medina Ascencio Local F16, Zona Hotelera, Díaz Ordaz, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6421227, -105.2332415,
  'https://lh3.googleusercontent.com/p/AF1QipO93qNDX60vg6fyUEvbTqmEC_XcAGkQ_NUmQeYS=w425-h240-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, 'http://barberosbarberias.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214551182aa127:0x4b864e37ec20a50f', 'BARBEROS PAROTA CENTER', '+523225961523', '+523225961523', '
Plaza Parota Center, Av. Francisco Villa 1010-Local 42, Jardines de Las Gaviotas, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6382277, -105.221827,
  'https://lh3.googleusercontent.com/p/AF1QipMADly1FhBHNpAZcXHV-wq4B5yvGwQUB04m5Ovi=w408-h271-k-no', 4.5, NULL, 'Barbería',
  '{cabello}', NULL, 'http://barberosbarberias.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214544737c6ecb:0xd7e18b276d806064', 'BARBERÍA BUNKER BARBER', '+523224031408', '+523224031408', '
Chimo 536, Jardines del Puerto, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6602543, -105.2317112,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerg3J2lqK397uIKnF2RUjsu8MiLib3ccYEwP3PRqP_QPglBlG_8lLMdQOdAYI92z9Qx5u7SFRrYB7SzHw8fww11d7GxWsI_C7VPuiIO9gFybE3f6jzxGW-UhXE8ZI5BML8MbXpUlA=w505-h240-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, 'https://m.facebook.com/campaign/landing.php?campaign_id=1655435892&extra_1=s%7Cm%7C318726445439%7Ce%7Cfacebook%7C&placement&creative=318726445439&keyword=facebook&partner_id=googlesem&extra_2=campaignid%3D1655435892%26adgroupid%3D63005051989%26matchtype%3De%26network%3Dg%26source%3Dmobile%26search_or_content%3Ds%26device%3Dm%26devicemodel%3D%26adposition%3D%26target%3D%26targetid%3Dkwd-541132862%26loc_physical_ms%3D1010084%26loc_interest_ms%3D%26feeditemid%3D%26param1%3D%26param2%3D&gclid=CjwKCAjwx6WDBhBQEiwA_dP8rW9GI7Bp-j53jJ2j-nF0lMv7hZaoOJGddG_oSdVhX7N7WnovOp5sxRoCxIQQAvD_BwE#!/profile.php?id=103876521719127&ref=content_filter', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f04ec181065:0x101d364344b08703', 'BEAUTY SALÓN by Brenda', '+523223184732', '+523223184732', '
República de Ecuador, Calle Miramar 276, Alameda, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6537558, -105.2097018,
  'https://lh3.googleusercontent.com/p/AF1QipNlVO5bYj6SyVpdMHDPaDNZoCxioFtKkg7Xgw6C=w427-h240-k-no', NULL, NULL, 'Tienda de belleza y salud',
  '{cabello}', NULL, 'https://www.facebook.com/Beautysalonbybrenda/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421473a16e540ed:0x4d81d0e19fcf02e3', 'BRIANDA DOMÍNGUEZ NAIL SALON', '+523222938818', '+523222938818', '
Blvd. Nuevo Vallarta No 7, 63735 Mezcalitos, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7101565, -105.2824141,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoE9BtgiuGSmcUw3483t9fX0KiEyLKr8Ob6m0SM5rJQlEalyOyFvHomC5uyUv-YOkoZvd-3-DqV3HeRVa0jsCAwFT33Lw3egoO9rm58K01T9RSgQZApAuMO9_0gYH-CS49_aZc3=w408-h544-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fac98396c5b:0x6dd509cc8346b8c0', 'Baby lashes', '+523223734930', '+523223734930', '
Ramón López Velarde 580, El Magisterio, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6723074, -105.2103565,
  'https://lh3.googleusercontent.com/p/AF1QipOBWhYJSCJhfmJYL7dKOoRVLhSTZBhdWkj3rgAo=w408-h408-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.facebook.com/share/17ZH1bhnAv/?mibextid=wwXIfr', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421477ae884aa9b:0xf443cdce0b3d08a3', 'Bahía lashes', '+523221803069', '+523221803069', '
Plaza El Roble, Blvrd Riviera Nayarit 2-local 13, 63735 Nuevo Nayarit, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.709195, -105.2744838,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqQR3DWZ7HWcL-QWI1Wv-jbtkE7i0Nn5P-I7oc2hh4f88gtEP6rk30cPK1S41Ueo9OfBTyfEN3haGd_Ri1uPuts7Do_fcc0SV_lhuInt45lt0_VoE7VRt7qsQbmxnEvLSPz99zS=w408-h269-k-no', 5.0, NULL, 'Eyelash salon',
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454b4cca1a9f:0xcdfce1cce9d3e16', 'Barber & Booze', '+523222228554', '+523222228554', '
C. Rodolfo Gómez 122, Zona Romántica, Amapas, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6000382, -105.2380363,
  'https://lh3.googleusercontent.com/p/AF1QipPzApLcp1fk0Url-gzZluZQxSuUaXnQ7gKX80kG=w564-h240-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, 'http://www.barberbooze.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145e9a343843d:0x3932b7e1d15d87f2', 'Barber shop didier ( peluquería)', '+523228893546', '+523228893546', '
C. Perú 1372 a, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6209385, -105.2301526,
  'https://lh3.googleusercontent.com/p/AF1QipOmwFMBQlR4KwAikcG1SC1t-lJcJjbaLffRBhvX=w408-h725-k-no', 4.9, NULL, 'Peluquería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452f64eeda01:0x85ec7c3ede231785', 'Barbería Versalles', '+523224038938', '+523224038938', '
Viena 350-Loc 3, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.634711, -105.2257983,
  'https://lh3.googleusercontent.com/p/AF1QipMdwnD12EbFM8sWoB2LaVnNJoQBzAZeWoUgDrRr=w408-h544-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457f3769b62b:0xede0de7fbf30e3f9', 'Barbería malecón', '+523222657826', '+523222657826', '
Leona Vicario 125, Morelos, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6127649, -105.2333789,
  'https://lh3.googleusercontent.com/p/AF1QipMUpIHaFuDzpglM_yTHrAF8QPPpvGP10NteNu6t=w408-h544-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214560f5cdaa6d:0x5c1c02baaa80f4dd', 'Barberó Barber Shop & Tattoos Suc. Galerías Vallarta', '+523222213845', '+523222213845', '
Av. Francisco Medina Ascencio 2920, Educación, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6583594, -105.2394273,
  'https://lh3.googleusercontent.com/p/AF1QipOhyzcFgLK7hBi5okLCFLvLAZerDwQc2LTLhFYE=w408-h272-k-no', 4.3, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b8c878972d:0xedd066acf224cb39', 'Barberó Barber Shop & Tattoos Suc. Marina Vallarta', '+523222213130', '+523222213130', '
Calle Popa, Av Paseo de la Marina, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.666948, -105.2497342,
  'https://lh3.googleusercontent.com/p/AF1QipOGd50NLjkrBCu0Xuhfdf_Ts5_0fgtxLvIwb5fh=w408-h272-k-no', 4.5, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, 'https://linktr.ee/barberoconacento', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454260f09645:0x3c52615f6b820d4b', 'Barberó Barber Shop & Tattoos Suc. Walmart', '+523222080377', '+523222080377', '
Blvd. Francisco Medina Ascencio 2900, Educación, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6562391, -105.2383737,
  'https://lh3.googleusercontent.com/p/AF1QipP6hJU5OofCoKaTK3zC1oJ-VVuoNz_RFaHcWzP0=w408-h543-k-no', 4.7, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, 'https://linktr.ee/barberoconacento', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421456f421d6121:0x3661f7f4a1089c9a', 'Beauty Salon essence', '+523222426519', '+523222426519', '
Blv. Francisco Medina A, Zona Hotelera, Zona Hotelera Nte., 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6346926, -105.230946,
  'https://lh3.googleusercontent.com/p/AF1QipO3Ohqbe3_FCoM4ArNLUt5saFiyfw1hpgDPR_Df=w408-h272-k-no', 2.4, NULL, NULL,
  '{cabello,uñas}', NULL, 'https://www.facebook.com/www.essencebeautysalon.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145002c973d55:0xd4fd6076416ff663', 'Beauty Salón Arely', '+525575166774', '+525575166774', '
Av. Francisco Medina Ascencio, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6418364, -105.2324826,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerauRqCLKwFqFjVUjqxfwMkCUAoRjlvu0t7hkUPsvMkI4XZ7chysoUaHq6ufyZ54ZHMXfJSa56wTL3w-dRMZYK-oikmRG3OOT-LKrWD-jlMuGqq49SymiOoZgNuZLoCyHEZKtRVRQ=w408-h544-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454311f0d057:0x79be1cec72a9c522', 'Beauty Salón Ken Daniel 2022', '+525549149741', '+525549149741', '
De Los Tules 204, Jardines de Las Gaviotas, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6390453, -105.220217,
  'https://lh3.googleusercontent.com/p/AF1QipO5UckkhcMFKWkdhdBPvKArK-EEa4jI7tvp-UNt=w426-h240-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/profile.php?id=61563530581657&mibextid=LQQJ4d', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145bb232b9eb7:0x8730e4105cc4816b', 'Beauty Salón and spa Lety', '+523221130202', '+523221130202', '
C. Perú 1110, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6165001, -105.2308912,
  '//lh3.googleusercontent.com/ojD1t5OV5ceRSWXbxTZw6074F0LX4Y5WZkmMDL3I5BvU2CQgZ347663dSNEaLlKh=w427-h240-k-no', 4.6, NULL, 'Centro de estética',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145a03471360b:0xbaf03692b5bfdcde', 'Beauty Studio FG', '+523223605597', '+523223605597', '
Normal Superior 144, Educación, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6615342, -105.2391139,
  'https://lh3.googleusercontent.com/p/AF1QipPdruH6wUR7jRyFPuqGO-f3XCgstZwzm0uk_cO2=w408-h408-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f86a4d249db:0x2a862cb78329f9ac', 'Bibrieska''s Eyelashes', '+523221027527', '+523221027527', '
Condo Los Sauces, C. Cardenal 175 col, Aralias II, Fovissste 96, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6436289, -105.2153379,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqwf2EMeGOXBbmyhdPjYHOOx6xEDEVTGEPkdCkNtG_GLzNH4sABPCa6NWgzUfZ-gbpS3TkRLn1qFvVZoC5DDu8PJl3DpXGMtfq67pb3cHPs9VfD2jKBg8B1u6OMcYWStMfSAw5x5g=w566-h240-k-no', 4.8, NULL, 'Eyelash salon',
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145edaa331073:0xcc78c1b155f2a687', 'Biker''s Bar Barbershop', '+523226884142', '+523226884142', '
Lázaro Cárdenas 328 Colonia, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.603759, -105.2343716,
  'https://lh3.googleusercontent.com/p/AF1QipOiRc5LwYfSIGErXG-ufUJlKTtlSImDptPrvk0r=w408-h374-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214570c879fa2f:0x6f7533d9bab0057', 'Bissú Boutique', '+523222243238', '+523222243238', '
Plaza Caracol, Av. Los Tules 152, Local F-20, Versales, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6404219, -105.2327849,
  '//lh6.googleusercontent.com/hVvggOBOXJsIVvNqUjTsVhvZ8DRxA-s4oJudYxrelwOqkiEobMwQALpvA2Q7UKud=w427-h240-k-no', 4.1, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, 'http://www.bissu.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421451568a0cf6d:0x45ffa783b1f9d8c9', 'Blue Hair Studio in PV', '+523223828457', '+523223828457', '
Plaza Neptuno, Blvd. Francisco Medina Ascencio Km. 7.5-Int. A-9, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6675913, -105.248417,
  'https://lh3.googleusercontent.com/p/AF1QipMPfmv13jrvZpy9nT6OT5PKAeicudOJydpHrk9-=w408-h343-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/Bluehairstudiopv', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454b5b26c82d:0x4b262030ea95d383', 'Blue Massage Spa - #1 Massage Puerto Vallarta', '+523222226034', '+523222226034', '
Olas Altas 411, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.601219, -105.2376574,
  'https://lh3.googleusercontent.com/p/AF1QipOIkXg5yeLG6qwAvcUbFxobzFkYyVhlhiuymwoc=w426-h240-k-no', 4.7, NULL, 'Salón de manicura y pedicura',
  '{cuerpo_spa}', NULL, 'https://www.bluemassagepv.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145664addda97:0x2772c2eb7a3c66ae', 'Bonita Make Up Studio', '+523222277441', '+523222277441', '
Francisco, Av. Francisco Medina Ascencio 1686A, Olímpica, 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6269826, -105.2295551,
  'https://lh3.googleusercontent.com/p/AF1QipN-OCy0ya6UrYDopEB_BnggszUc4ib5VJf6yXHO=w408-h271-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://bonitavallartamakeup.com/services/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842148a1a293bc5f:0xdc062539ded85360', 'Bonita sala de belleza', '+523221832554', '+523221832554', '
Flamingo #112col, Los Tamarindos, 48280 Ixtapa, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7157714, -105.2152401,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoo9zknfbPTVCtEkBleAV_SCyv0pYFB5IgiTjZh1j0cEBCMpyIQB6yYQYoiWqTc-CCiQSf79a2NMJDX6OQb-kr3Wt7HpKagxONw6rQrBf936-sHr-YZh9eAU2TPmwI2MO972KVtdZ256QM=w408-h306-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://m.facebook.com/pontebonitaconkarlahernandez/?locale2=es_LA', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145d8e106092d:0xfcf606e7efc825c2', 'Brida Salón', '+523221201530', '+523221201530', '
San Juan de Dios 112, Santa María, 48325 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6278311, -105.2224947,
  'https://lh3.googleusercontent.com/p/AF1QipPeYGTHrVVxjmYyWyGXPz1d4BZKbc2v6OCvp6ik=w408-h725-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842140c8a650f773:0x3ddb5c2b555de4e1', 'CHEDRAUI BUCERIAS', '+525555632222', '+525555632222', '
OXXO, BLVD RIVERA NAYARIT ESQUINA AV. LAS PALMAS. 596 A 100 METROS FRENTE AL, 63732 Bucerías, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7503719, -105.3246463,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqH4qUH1RHb6nh3JOl4oiFz7eEGFTijqopGkBlDSlqAHK_Ve8XiIeOR6qhYbckv5IafW5TZuHGLNvuqsC-YC2eHEso0eWmLNBTBnoHpL0f1wNMkinw3NwhGpUcp9kKgrwrATbJG=w408-h306-k-no', 4.1, NULL, 'Supermercado',
  '{cabello}', NULL, 'https://www.chedraui.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145f922500b57:0xbea83e3ab3d54c80', 'COCO HAIR SALON', '+523221706434', '+523221706434', '
Basilio Badillo 423, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6031297, -105.2322182,
  'https://lh3.googleusercontent.com/p/AF1QipNh_7HgdYDM0yNhQ6yywt8iR2DyDRS9xE86wbaF=w408-h544-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421459b6aaec1d3:0x9f764ffe94396ede', 'Calme Estudio', '+523223819848', '+523223819848', '
Lib. Luis Donaldo Colosio 550, Lázaro Cárdenas, 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6264052, -105.2244614,
  'https://lh3.googleusercontent.com/p/AF1QipP9qInSQivoGxtqSbgm09ztsqOv3LA6usmES0rX=w408-h544-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/CalmeEstudio?mibextid=LQQJ4d', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457cef11d937:0xd0a3589c24469c34', 'Cami''s Lashes Studio', '+523223814346', '+523223814346', '
Francia 140, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.634762, -105.2286707,
  'https://lh3.googleusercontent.com/p/AF1QipNovA_SCxtXFV1HvxYeMACZPTiFQirlUaxbM-Lg=w408-h299-k-no', 4.8, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.facebook.com/Camis-Lashes-103521267877433/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145c2c0cf5ab5:0x6837a53d6f08e15e', 'Campeones Barber Shop', '+523222005664', '+523222005664', '
Morelia 136, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6309326, -105.2272568,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwep-tb9U7iizF-y9xCaUhU6KEldivWbK8hFm4M6pNEPAKmHzaRlETlM_efcTwIRYjIn8dL-6_Dnf_3_Lj9-yaWZmp-AEHB0ADqryHDnfjNtz6S8_eKECpB-odni7MpkeGRLAT2LvWekAbbSo=w408-h544-k-no', 4.8, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, 'https://www.facebook.com/campeonesbarbershop/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145141b10028b:0x59b23dd5694f962', 'Carlos Barber Shop', '+523221706291', '+523221706291', '
P.º de La Viena 167, Las Gaviotas, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6323194, -105.2217967,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=CP7nA0c5QiMMbJJwrHW87Q&cb_client=search.gws-prod.gps&w=408&h=240&yaw=6.3284225&pitch=0&thumbfov=100', 4.7, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421456564f93e57:0xd6f17e37af530bd', 'Carlos Coiffeurs Hair Salon', '+523222248044', '+523222248044', '
Plaza Las Glorias, José Clemente Orozco 1989, Int. A-8, Zona Hotelera, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6334999, -105.230662,
  '//lh4.googleusercontent.com/za-5lddvghmGdl1a5oMFx2FTC_T2-0gxQhr5NaOfWaYMa3_Toi_4KllnO4r_HbE2=w408-h726-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b8b6f66621:0x923b48db1f4cff5d', 'Carmen''s Bliss Spa', '+523222213132', '+523222213132', '
C. Popa Local 03-B, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6668901, -105.2493956,
  'https://lh3.googleusercontent.com/p/AF1QipN0kSYrRWNYbPkaJX_V7sHY3MicIKXYx0fK0PUZ=w648-h240-k-no', 4.9, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'https://www.facebook.com/CarmensBlissSpa/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145e7d198286d:0xf1728467001cf6c1', 'Cecilia Sánchez Salón', '+523222896597', '+523222896597', '
Pizota 547, Jardines del Puerto, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6607545, -105.2305084,
  'https://lh3.googleusercontent.com/p/AF1QipMYHVxo55KIqYm1cHkRVzlRPKiIRHMM9OXAmNyr=w408-h544-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.facebook.com/CeciliaSanchezSalonBelleza/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421441f7098b04d:0x6b14cccd287ac326', 'Chaac Spa', '+523222211040', '+523222211040', '
un lado de Hotel Melia, Av. Paseo de la Marina Sur s/n-A, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6602827, -105.2529584,
  'https://lh3.googleusercontent.com/p/AF1QipOBauE6ZaKUQv2k6JyGJIQAuYp9ar2e2lF5M4Hs=w532-h240-k-no', 4.4, NULL, NULL,
  '{cuerpo_spa}', NULL, 'https://www.facebook.com/chaac.spa.9/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145e07aa25129:0x501e5863800c4687', 'Classic Man Barbershop', '+523221628060', '+523221628060', '
C. Popa, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6674379, -105.2491656,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepKRYPO_B8H5X72cmQgR84ux4FDqjsJ-vOnHvPZROWRaBh5q1WmHLHjl0T8K0ZZEcyYUCcE5FGp42NMBlliPBFytztBrsVpI9W8BD4AL5ohZYPQ_0dplVin9170CcZG-pvGA2Q16A=w408-h544-k-no', 4.9, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421459ddb94ad87:0x8a9abbf8e9be4144', 'Claudia Peluquería', '+523221388734', '+523221388734', '
Francisco I. Madero #323 Col. Emiliano Zapata Col, C. Fco. I. Madero 323-Local 2, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6044584, -105.2346583,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweo7QOY4Z5KPt7ceKvk8V-5ncQ0j2xblcVPNC072fwWzLAzpSFWWKBbu_dqiWB2t_f941i65ncN-Mc2WB1LF-zBPsDUlZKi85yRM2OD7c4Kmzvuc3dbFTuS_iKGCouWZH_4jXokioA=w408-h544-k-no', 5.0, NULL, 'Peluquería',
  '{cabello}', NULL, 'https://www.facebook.com/Peluquer%C3%ADa-Claudia-278493226105886/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f817f349f79:0xe11c17b67fd20734', 'Clinica de Belleza Betos Unisex', '+523222934125', '+523222934125', '
Fidel Velázquez 568, Infonavit C.t.m., 48318 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.645556, -105.2140533,
  '//lh6.googleusercontent.com/syivsyTzloI9lIsnldQvciOeHf1URe0NeTa20D40mfl-DtbHTgUlapf5FzbqQvECRQ=w427-h240-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214574943948a3:0xde0d011f9a377620', 'Clínica Arte Cuerpo Medicina Estética, Stem Cells,Depilación Láser reductivos y faciales.', '+523221695917', '+523221695917', '
Av Fluvial Vallarta 260-Local 6, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6427962, -105.2298893,
  'https://lh3.googleusercontent.com/p/AF1QipPkf3IsC8pFUjhGdvc5ZyAhKuU3GwX6ZtRPJCN-=w408-h408-k-no', 4.9, NULL, 'Clínica especializada',
  '{facial}', NULL, 'https://artecuerpo.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454518692edb:0x4d535bd8fea63a90', 'Colorizimo Hair Studio', '+523221130160', '+523221130160', '
Plaza Iguana, Av. Francisco Medina Ascencio 2899-Local 8, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6632942, -105.2458278,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqwME50TNlsLN-vSEyr04NKOAFbvjyLUXHZ74ZTAYdy0eNdag5Gdz-wfdd5QrFHRdao9dI_a7bo96JfHDizu7Gqhnz1T2SRgObEAkEVDckr0fKlA3VEHQrNzBNj98zBU2qFTraB_Q=w408-h306-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.colorizimohairsalon.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145773a519441:0xee39dce33726c84', 'Cosmetics and Colors Puerto Vallarta', '+523222247898', '+523222247898', '
Av Los Tules 178-Local 17F, Díaz Ordaz, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.641973, -105.233155,
  NULL, 3.1, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, 'https://www.facebook.com/CandC.PV', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145af86eac19d:0xc5f479b89383ce31', 'Cutie Nails (Salon de Uñas)', '+523223691718', '+523223691718', '
48315, Las Arboledas, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6593216, -105.2276642,
  'https://lh3.googleusercontent.com/p/AF1QipOeFEb3EzQp-TvpzGRb6WLh54Lpkm3_XSUF0fz9=w408-h725-k-no', 4.9, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.instagram.com/cutienails_andy/profilecard/?igsh=MTdqYTM4OWcxazRtZg==', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c8e81f639:0xafc7b5ef9a329d27', 'D'' Martha''s Salón', '+523222230405', '+523222230405', '
Ignacio L. Vallarta 326, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.602587, -105.2359406,
  '//lh5.googleusercontent.com/ORaISWRL1pc1PyJkQLwikeSC13Sfi8Tpfr5LhTehc37BUzlNo4PV53SesRpaobhZ=w408-h726-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f85c79e66ef:0x738a2c79c28ea53e', 'D''Rocio', '+523221082569', '+523221082569', '
Allende 366, Independencia, 48327 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6394343, -105.2123333,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepLzoNYLE4UyvCTxdbW5OrJbBm8E4UZbRozKHfwHLqypK3wnJwDFLIk-9mGpjtVeRbReKiCf950QjIAbISqM_Utz1d_WPy4PL5U34IAqCCCWgrR_-jnP23hy4DYI3JWeEivL-mBnw=w408-h306-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454ee49070fd:0xe91b427e41e0e886', 'DISTRIBUIDORA YANIN’S', '+523221995752', '+523221995752', '
C. Juárez 854, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6131978, -105.2319422,
  '//lh6.googleusercontent.com/TdoNgWAjFMl_YDK5UwfwNsQk6p5dOECv11XT2DYcMVYQ575AQpZyn4adYYvW3Epu=w408-h726-k-no', 4.6, NULL, 'Tienda de accesorios de moda',
  '{cabello}', NULL, 'https://www.facebook.com/yaninsProductosdemodabelleza/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145597c021c47:0x7a3ae01165fd0047', 'DULCE MALANDRO BARBER SHOP & BOUTIQUE', '+523224399338', '+523224399338', '
C. Politécnico Nacional 255 48338, Educación, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6616566, -105.2364722,
  'https://lh3.googleusercontent.com/p/AF1QipP7THEPDOt3h07WBlZzg-7XNinaHWfXrTcvDIxN=w408-h873-k-no', 4.4, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, 'https://www.instagram.com/dulcemalandrobarber?igsh=MTRjZzIzY2Q5Zmg5NQ==', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84215bb920b74f5b:0x35f7e8bb05ad3c87', 'Day Spa PV', '+523222210176', '+523222210176', '
Timón 1-A, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6644066, -105.2528058,
  'https://lh3.googleusercontent.com/p/AF1QipPqvfrXjzis0Z7vT3AOEpcGR0IWuRDKiPEaQDWW=w408-h306-k-no', 4.7, NULL, 'Centro de salud y bienestar',
  '{cuerpo_spa,facial}', NULL, 'http://www.spapv.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145c9428eadb9:0xfd5572217ef1225c', 'Diamond Nails Spa', '+523223489034', '+523223489034', '
Francia 203-local 8, planta baja, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6371381, -105.2275727,
  'https://lh3.googleusercontent.com/p/AF1QipNDOhyYFNRwKN4fbeCOt-gfVYF16dtrRPUk9kN-=w408-h543-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{cuerpo_spa,uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b72020089d:0x470b61a19cacb8e6', 'Diva by Lya Contreras', '+523221216063', '+523221216063', '
P.º de La Viena 126-A, Valentín Gómez Farias, 48320 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6321443, -105.2220085,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer56zBbpx_JJUab3Nmw7qRJW3JeDQnYCCaLcOMdzb7QY7c1oppcWSiKShwgE0skn91rhZ5s2wy56udOqeSVMD8uhesbLz_BLAU0_Q9tP4WkOMXAlWxbJfw1C7mIcbrdDsNED6g2w6r80JiX=w408-h544-k-no', 5.0, NULL, NULL,
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145dcfd9db293:0xf8f0e4bf726ac649', 'Divinas Lashes & Beauty', '+523221824188', '+523221824188', '
Independencia #405, Bobadilla, Lote pitillal, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6532144, -105.2216885,
  'https://lh3.googleusercontent.com/p/AF1QipMsccxgQeFzPS4jeuF_Bf1dskd0gf2It1rED-ay=w408-h544-k-no', 4.7, NULL, 'Centro de estética',
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421456547991a21:0xa2fbd06b57e5ba31', 'Dream Spa Massage', '+523221020093', '+523221020093', '
Blvd. Francisco Medina Ascencio 1989-Local-14 H, Zona Hotelera, Norte, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6339976, -105.2305201,
  'https://lh3.googleusercontent.com/p/AF1QipP6vGFFOtM6at39rHKZ5lnVSwsgZ8lTk_K8GpVc=w426-h240-k-no', 4.9, NULL, 'Terapia craneosacral',
  '{cuerpo_spa}', NULL, 'https://dreamspamassage.webnode.mx/reservar/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c7531a9e1:0x324d074be3484a72', 'Eclipse Spa', '+523222220614', '+523222220614', '
Aquiles Serdán 222, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6044939, -105.2368598,
  'https://lh3.googleusercontent.com/p/AF1QipPQyd1emHJJU27w77UeuExfsNcyFIXUwOATDg11=w408-h306-k-no', 4.7, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'https://www.eclipsespa.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c88f0b25d:0x3e58b261ad4852ce', 'Eco Salon Sebastian', '+523222220331', '+523222220331', '
Venustiano Carranza, Pino Suárez 202 Esq, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6026873, -105.2368806,
  'https://lh3.googleusercontent.com/p/AF1QipNiQrv_snzSUHpxAGrYTcjfZXtNbtAEvOfeqpFS=w426-h240-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/ecosalonpv/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454f8ff45e19:0x4f65b1ac30cfc0de', 'Eddie*s Hair Salon', '+523222091249', '+523222091249', '
Abasolo 191, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6113884, -105.2333761,
  '//lh3.googleusercontent.com/UtakDLe81-4lT_sRJQDF4uaeLRkJbv6XSWaLfenJzxBy7DzL9Qcmy_EFOlba0vo=w408-h726-k-no', 4.7, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214563b4367b39:0xf78d6cd81aa6ba57', 'El Salón Twins', '+523221174006', '+523221174006', '
Paseo Benemérito de las Americas 238, Valentín Gómez Farias, 48320 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6314432, -105.2241064,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweo_ccD5xUJPV-e4-RWxB1g_2VBpD6_kb_1hGWl-q0g5WagJFZw2WNDKJHMVjRb7szcVnQjjaMN-104WGS4LuTYHXWGHVfeUUNHSiDoNqmxfWXIZP7IqrNVuaYUATxXtrSpWsvP44g=w493-h240-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/elSalonTwins/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214550000d950b:0xe9625b85ef66dace', 'Elite Kids', '+523223654144', '+523223654144', '
C. Prisciliano Sánchez 519, Las Moras, Villa del Sol, 48314 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6558173, -105.2318226,
  'https://lh3.googleusercontent.com/p/AF1QipM4GIkNGKjuZgIiSBXjPdQbVeNgkhh7dVKhAm-l=w425-h240-k-no', 4.8, NULL, 'Peluquería',
  '{cabello}', NULL, 'https://elitekids.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145ac6ca3aa67:0xb74a73a110df15e6', 'Elite Spa Massage', '+523221901831', '+523221901831', '
Manuel M. Dieguez 183, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6016503, -105.236918,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepYOXGW1yDS1Ybm9bUnlhGXXiK5zOJoiKK_9KdN5f4ZtWzu5kFSUUDB3LAUfCrQuDUbOO6MCsm3eZ4QiVLVYTiduLPiLN_SIeopokkq1C4br_1W2ZKKKr5WOf1s8MHrFQewJDiV=w408-h724-k-no', 4.8, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'https://elitespamassagepuertovallarta.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145c19d9ff43b:0xbe589c4bdc36ec89', 'Elsa Beauty Studio & Art', '+523221073343', '+523221073343', '
Mar de Cortes 614, Palmar de Aramara, 48314 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6538199, -105.2340619,
  'https://lh3.googleusercontent.com/p/AF1QipNv5PrAP29kFJqfpPHD8SqzDRk_jkgr30sW2yPL=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f4fca42b073:0x2ed2527c9019c0', 'Estudio Bella Esmeralda', '+523223801690', '+523223801690', '
Zanate 304 colonia, cañadas campestre, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6936113, -105.2069158,
  'https://lh3.googleusercontent.com/p/AF1QipMUYbKTURXE3OYkNSPHbFOnaVv40Zl1upTo8DDC=w408-h352-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{cabello}', NULL, 'https://www.facebook.com/BellaEsmeraldaNails87', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f86b4870dbf:0xbc520d0ca656ab5d', 'Estética Alis Mar', '+523222254042', '+523222254042', '
Av. Las Torres 132a, Fovissste 96, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6425849, -105.2148444,
  '//lh6.googleusercontent.com/TPLlYyyPIs30lF3k8R1E0BW9X_1JqS601o9P5gABYorjHDLxDqHle6Kijs3KREL80Q=w427-h240-k-no', 4.4, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214586c3236513:0x68c99025d358738f', 'Estética Bere Nice', '+523221359137', '+523221359137', '
Edificio media luna, C. Prisciliano Sánchez 550-local 1, Bobadilla, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6525208, -105.2215372,
  'https://lh3.googleusercontent.com/p/AF1QipMn1C9GqX3AWFd7EJDm8v3Fyz255NsS8ggDkwwz=w408-h544-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/BereNiceSalondeBelleza', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c39f2010b:0x6ac3744d2d962ddb', 'Estética Brisa', '+523221754654', '+523221754654', '
Aguacate 402, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6048032, -105.2329109,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoHwemIl2W0VXYVTILtdWVigCsFVk3dsMX3dPzA4av-xXwBWvw9tcMTy6sO0z-5hav3-nTfDuIdvr292A0gGW705Tj_d20dcgE28gPAogCRkuMQc3BnEX80esF2IcMlxmG5dEzRzg=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214576973a3c15:0x6ac26d8dd6f2f6f4', 'Estética Elba', '+523222090067', '+523222090067', '
Av Paseo de la Marina 161 Sur-Loc. 1, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.66596, -105.252769,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoI2blYCidxxIf-y2Xf_OVY6KeXktPuvApZlYnH44x_IFi7_vhT8eDekBCrW1BnhxibVttNAfrXPGzmO_uX-EGzDXAugn1nlbjFshHEr37rupFN8MT2BV1LW9XTEi7BtXHndVjR9A=w408-h408-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://esteticaelba.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214570b78c0177:0xe9e507be73d5f8e6', 'Estética Escorpion''s', '+523222240952', '+523222240952', '
Plaza Caracol, Av. Los Tules 156, Loc. 26-F, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.640193, -105.2325583,
  '//lh4.googleusercontent.com/wAHlxcSX-mu5-hUdRX_jDrBCIPvluLDWoDl1_EBForrhwpM0i_BTld2DUtcHNMJB=w408-h726-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145888c90b6eb:0x9c9026b2802a2ef', 'Estética Esmeralda', '+523222030458', '+523222030458', '
Zacatecas SNS, Las Mojoneras, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6877041, -105.2253147,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepdUG8K0Lg0HaytbW-N25UGACCZQQcNFKIjcRp-KYttpfvp2ABfNqWuvy3Sxb1omyd57z5ZnA3nw2FfFQJWaxTmbQ06YNZdGkZ0KyP-N6XgPQ338kISukM9Pf_032V_7zRZoYiw=w426-h240-k-no', 4.2, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145651b8b0b51:0xacd20227e4915066', 'Estética Especializada en Micropigmentación y Faciales – Ponte Bonita', '+525632177312', '+525632177312', '
Abasolo 128 A, Leandro Valle, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6511533, -105.2203717,
  'https://lh3.googleusercontent.com/p/AF1QipPv0yzLqjuHlBcUSExiGcFto5V2cphBEpki7daw=w408-h306-k-no', 4.8, NULL, 'Centro de estética',
  '{facial}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421459bc7eb7905:0x40d8ddf1bc9c3a1a', 'Estética Gemelos', '+523222097260', '+523222097260', '
Océano Pacífico Pte., Palmar de Aramara, 48314 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6545505, -105.2356385,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwers5axVWDRHXghP3oirqc2k1YJaNM2olHnmh1ZMFWt9GJMM1APz0dVoUenebkE2yQE401KC5uDB2bcr1mK6GifNmdeh-Ikj3ngQsGc3q5QE5DqnNXtzwtnO5G5TCD8mnRvLlATTdQ=w408-h544-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454567f15bef:0xd6d0346860fe5391', 'Estética Italiana', '+523221111190', '+523221111190', '
C. Juárez 793 A, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6126083, -105.2324749,
  'https://lh3.googleusercontent.com/p/AF1QipOqHSvy-Y732z4jXkGyf9O2DUa0ExYlUSM_Ebjr=w408-h544-k-no', 4.9, NULL, 'Peluquería',
  '{cabello}', NULL, 'http://www.esteticaitaliana.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214564ca5a177b:0xa309b7ba43b79572', 'Estética Krizaly', '+523222241227', '+523222241227', '
Libertad 343, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6066696, -105.2347974,
  'https://lh3.googleusercontent.com/p/AF1QipPUs7my0HpTR1iCcwnq_SPQqadwaAqfyBUgcsXM=w408-h544-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f8184546587:0x6e8c8711e5cc2150', 'Estética Nena', '+523222242050', '+523222242050', '
Fidel Velázquez 607, Vida Vallarta, 48318 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6462316, -105.2141595,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepRykoknc_J8whz0YZYPDMrv8UBWu1vwlFe30sDQrCNsOjXBnXaNbxTLN7mBKHmnxRfCaHIrphcXhwvWGp4T44zFsSOUa0MbSVzFo1xy6Oa0rcdAhH35tqInxX9mdob2f52KuPkKg=w408-h725-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/estetica.nena', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421458870ea8621:0x430f716f7fe033a0', 'Estética Unisex Angelica', '+523223060671', '+523223060671', '
C. 16 de Septiembre 296, El Palmar del Progreso, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6599863, -105.2216186,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=kqDtAsnVXSRXtFPWLL2Q1A&cb_client=search.gws-prod.gps&w=408&h=240&yaw=202.27301&pitch=0&thumbfov=100', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7d61473d09:0xcd2700cf815a84b3', 'Estética Unisex Diana', '+523222139058', '+523222139058', '
C. Exiquio Corona 314, Bobadilla, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6580503, -105.2191266,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweq7a-XYkwt5pLJauTlStRfPO1hRkdYxrZv5_cIF0GczUfeFGykr8ydTfToDXh7viDKT_DEeI2uTl_BP3qzItr8CzpfiR0jDISXme2W2oyW-0rqvsFefUPanqMHnAebkrCbBvZRC=w408-h544-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214593221ecfdf:0x80719ab1f2a42aa3', 'Eva Nutricosmetica', '+523222309804', '+523222309804', '
Ignacio Peña 109, Primavera de Vallarta, 48313 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6501025, -105.2218872,
  'https://lh3.googleusercontent.com/p/AF1QipMXCMeZkqLutEU7N4Qp2bFDuMvOBvwroJJI0Nyf=w408-h408-k-no', 4.0, NULL, 'Tienda de belleza y salud',
  '{cabello}', NULL, 'https://empresarioseytu.omnilife.com/co/antioquia/bello/3175026818/eva-luna-pernett', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145000fa62e21:0xbe399a2656897a92', 'Evangeline’s Salón & Academia de belleza (unisex)', '+523224294888', '+523224294888', '
De las Garzas 184, campestre las cañadas, Campestre las cañadas, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6961587, -105.2104765,
  'https://lh3.googleusercontent.com/p/AF1QipP9aTajYNyEzSaUk7VT_MOE0D1YO8EpLrVZ5lCl=w408-h405-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214599da66f8df:0x1f8d47f3fac3f839', 'Exotik', '+523227799428', '+523227799428', '
205, Av. Francisco Medina Ascencio 2920, Puerto Vallarta, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6577897, -105.2390673,
  'https://lh3.googleusercontent.com/p/AF1QipMa4_z1TS7uPln8wAtovt29haG8hHfq2xvvG60u=w408-h429-k-no', 3.8, NULL, 'Tienda de accesorios de moda',
  '{cabello}', NULL, 'https://exotik.store/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455b7b48ab3d:0xd6243743b0914a5b', 'FR Studio', '+523221986654', '+523221986654', '
C. Prol. Brasil 1257-3, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6188717, -105.2294235,
  'https://lh3.googleusercontent.com/p/AF1QipOKgglnRifDDNZNxu_dCeCipfRP_DD8AYF0CcKG=w408-h544-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.instagram.com/fr_studiopv?igsh=NGp0czVyNW0wcHg2&utm_source=qr', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147a8c7782349:0x8cea11ae9e159974', 'Fabeaulous Nails Lounge', '+523223220498', '+523223220498', '
Valle Dorado, 63735 Valle Dorado, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7124075, -105.2755698,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepEq9C4CYQ-ZQnVmgHF5MxQZyv2o0Jwzi9b5Ne0SeSc3RI8dVGppPahNRvfj6YsWID8wDSvRuiB4m-pLa8wYoLRksIoLTllxXm9fvG-nNoiuGZ_at7espaAbn_4jKqWrwYr-0htLM0OBsM=w408-h544-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454ec410f3b7:0x7638f76f729bc521', 'Fabian Oropeza Makeup Artist', '+523221313725', '+523221313725', '
Primaria 164, Educación, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6599705, -105.2382799,
  'https://lh3.googleusercontent.com/p/AF1QipOp5JL0hQ7dpfI7uIOnBLy3LRavncjxmUWEPggl=w408-h272-k-no', 4.8, NULL, 'Centro de estética',
  '{maquillaje}', NULL, 'http://www.fabianoropezamakeupartist.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145429df3e1b1:0xd8a7518a6f09d57b', 'Fernny Nail Art Studio', '+523221469838', '+523221469838', '
Universo 2007B-apto 31, La Aurora, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6562987, -105.2361513,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepDrcPWESv8iyNw_pDxxkv2vWHmsCz58hib6ybJfowhXA0D5rxDyhD_aZaxP8a2xjjtckGcZFEcPP_HGw2WWlWGUGTSZPU7dr616PU8NEGMhQeVuyzMemfNdH1ZMJeQl87xLwzl=w408-h544-k-no', 4.9, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.facebook.com/FernnyNails?mibextid=ZbWKwL', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7dfd66c97b:0xc5095fcbd37d0457', 'Franc Gole Hair and Makeup', '+523221809358', '+523221809358', '
Arrecife Punta Allen, Las Moras, Villa del Sol, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6578485, -105.2304099,
  'https://lh3.googleusercontent.com/p/AF1QipP_He_lYKDv0wZibh2QXS9OtNbFGpjT4Ep1pw1F=w427-h240-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello,maquillaje}', NULL, 'http://francgole.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f8a080af465:0xe5f06c718ba9d17c', 'GLAM Studio', '+523221748858', '+523221748858', '
P.º de Las Palmas 187, Santa María, 48325 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6273082, -105.2190009,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepi_mrq1XoA7saRtZosqMen_g4gJ9t3R8nq2WnrGacD9WwPPez7Ky6mu6duXX9uCT_fBv_m00YIrAkaY2EQHA_7fz32Ny1xtMt6L3NbhKXjcDe_0AN2zZ6hyqesdTuwg8L3KcRE=w408-h544-k-no', 2.6, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455885a97d53:0x1e2589c28214bad8', 'Galini Spa Massage', '+523339458277', '+523339458277', '
C. Constitución 364, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6022599, -105.2348242,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=XPmAZykbcWrljs2GkZ_iug&cb_client=search.gws-prod.gps&w=408&h=240&yaw=199.34299&pitch=0&thumbfov=100', 4.8, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'https://www.facebook.com/GaliniSpaMassage', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214ff87f1f9397:0xadebdecfcffd29d5', 'Gin Nail studio', '+523316008226', '+523316008226', '
C. Prisciliano Sánchez 550, Bobadilla, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6438114, -105.2170955,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqfZNvjU9V4WP1QDFkiJjTk904woN09uViXtWeGys4Ul9YDrX7DFqQKVtOqp9RIGI4Bn70DtFIpcyXJIIHzFIrazGhli73sGUWnuLiFcn_21TB05NU-KvvQtkIdAB4QtpKXSM8K=w426-h240-k-no', 5.0, NULL, 'Centro de estética',
  '{uñas}', NULL, 'https://www.facebook.com/GIN-NAIL-Studio-109667983861238/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fd067a219b9:0x3db95402704507ed', 'Glam House Salón & Spa', '+523224034946', '+523224034946', '
De Los Tules 429, Jardines de Las Gaviotas, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6381581, -105.2180639,
  'https://lh3.googleusercontent.com/p/AF1QipM0XU8MAG4oP5qFGBR13CHOCfkLL-FRds-wcap8=w408-h544-k-no', 4.8, NULL, 'Centro de estética',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421470bb6cda39b:0x7038e39c4538fa77', 'Gonzalo Garcia Salon', '+523223601141', '+523223601141', '
Níspero 275, Los Encantos, Valle Dorado, 63735 Mezcales, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7215444, -105.2663391,
  'https://lh3.googleusercontent.com/p/AF1QipM35Z2s9v7ZyZVbSX-3qUxUvUpiSZeUEicQeGOi=w408-h612-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214596a7f5a9a9:0x1e4e57a2078056c7', 'HELLO Maquillaje y accesorios', '+523223801756', '+523223801756', '
Av Los Tules No. 178, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6416891, -105.2325359,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqnBIJq7Ys9bz9b-iPIQK12yO_vl6AHiaRilqc9BBEjxclzl1aLq_vmRH0scYlmYWqRyukQICjL2dt27CEQJBgxbGSRIrrtrk-Y8tyQ5LCR6XuYkzX8QNBQH0Swph2_plR4jLYb=w408-h725-k-no', 5.0, NULL, 'Tienda de cosméticos',
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455c2ae473e1:0xa808e4a3ef296b89', 'Hair Salón Belinda', '+523222934505', '+523222934505', '
Brasilia 593, 5 de Diciembre, 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6213359, -105.2254882,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqnO8qUlcZPdxA96EClHF3MlJ3HKSss8JMvhmtm0SQxWqzFDagVe1gKswCJweweLTE8q2h-sng-0jt9SwNINi8hjD0x8vrBjdgVWiTL434NV0usOrYVFYgWYfXQMCXdbt3pjVCVqbkc3x2u=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421478a480d414b:0x419b53e8a25ce55', 'House of Beauty | Medicina Estética y Antienvejecimiento', '+523322288200', '+523322288200', '
Parte Trasera de la Plaza, Plaza Marina, Gansos 200-Local 24 A, Marina Vallarta, 48354 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.671346, -105.2514612,
  'https://lh3.googleusercontent.com/p/AF1QipNAFrDuFuB-Ir9QxcfWX-U0ctaabl9yujs93IUv=w408-h678-k-no', 4.6, NULL, 'Spa terapéutico',
  '{cuerpo_spa}', NULL, 'https://www.houseofbeautyclinic.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f1c50c57fef:0x8b89bb1bb5efee71', 'Hunt Lashes', '+523223207836', '+523223207836', '
48290, La Floresta, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6670243, -105.2162724,
  'https://lh3.googleusercontent.com/p/AF1QipNQo8eSi1a0fTdtTlahp7y-lOG_VxA2u5hqhADu=w408-h725-k-no', 5.0, NULL, 'Tienda de belleza y salud',
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457fcbd9a44d:0xb2cd9d06164b0acf', 'Instituto Mayra Ramirez', '+523221357486', '+523221357486', '
Lago Superior 137, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.642882, -105.2255905,
  'https://lh3.googleusercontent.com/p/AF1QipMRdWksKejrbg999LG8Bvuic5iYgqVmO09tJCR3=w408-h247-k-no', 4.1, NULL, 'Academia de estética',
  '{cabello}', NULL, 'http://www.facebook.com/InstitutoMayraRamirez', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145d0675d50e9:0xb934f0c57b9e024a', 'Isordia''s Nails', '+523222177551', '+523222177551', '
Tai 11, Aramara, 48314 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6545676, -105.2324448,
  'https://lh3.googleusercontent.com/p/AF1QipPM7RLgMu5eJvUet94ftHvpRDGGNgmKaDKPk4aL=w408-h544-k-no', 4.9, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.facebook.com/Isordias-Nails-105304338114915/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f15e50bd521:0x4ff3dde919f62cd7', 'Ivette Lashes', '+529841655820', '+529841655820', '
20 de Noviembre 197, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6531621, -105.2187061,
  'https://lh3.googleusercontent.com/p/AF1QipMD9I1132Y8uMHMUORLQ0Kd4lxBU4M3rk392vLi=w408-h725-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fa3a1fd6bfb:0x4a7a55193420f588', 'J&J Barber shop', '+523221348089', '+523221348089', '
C. Revolucion 406 - B-406 - B, El Toro, 48296 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6523745, -105.2121303,
  'https://lh3.googleusercontent.com/p/AF1QipN3sxjmzldHgGKr7OTmt81RdUS2Q25O9KP16elj=w426-h240-k-no', 4.8, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f150b51a9a5:0x6e96d63f15ab738e', 'JB Stylo Barber Studio', '+523223856986', '+523223856986', '
Federación y corea del sur 1359, Federalismo, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.659936, -105.198498,
  'https://lh3.googleusercontent.com/p/AF1QipM1I935kq_mli-FYOI6H8z285Ds2edghCR72gT9=w426-h240-k-no', 5.0, NULL, 'Barbería',
  '{cabello}', NULL, 'https://l.facebook.com/l.php?u=https://www.instagram.com/jbstylo.art?igsh=eDBvMzUxZnhsZjU2&fbclid=IwZXh0bgNhZW0CMTAAAR4IlQoJ4qml1QrPRW0-2BVaGHcGQpyLwpQmgv0WIWdYbmm-XlzWTYx8BD2C7w_aem_XmmzI1KPswrv1oHYAyiu8A&h=AT2hIniFv_nbTKVHgp-pzWr2he6fsPua55J0JzV3qKPxGkZpsl04mYB1BjoewvnU93SFRQpaTYEml9PxfXnrHD8jAqkdbdpSJ-zddBSUCd1H4MSpTymHo5KgtnjmFOUuy1vjiQ', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421451c102ff533:0x951529d996ae3cdd', 'Janna spa massage', '+523228889574', '+523228889574', '
48330, Zona Hotelera Nte., 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6338492, -105.2314433,
  'https://lh3.googleusercontent.com/p/AF1QipM177EIVIiZ-YYKkRMCB0MOQCaeZPvCOXoCBJZo=w426-h240-k-no', 4.8, NULL, NULL,
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147912a4653d1:0xc7f1551952eb3a19', 'Jaqueline Belloso Lashes: Pestañas', '+523221172612', '+523221172612', '
Valle Grande 143, Valle Dorado, 63735 Mezcales, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7162752, -105.2719775,
  'https://lh3.googleusercontent.com/p/AF1QipN_yBTz_URhVVhiTm3mjXxnJ9MN49-n4XyBhYU_=w408-h408-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.instagram.com/jaquelinebelloso_lashes?igsh=Y2xudnhmZ2dxYzls', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421477f3c726c93:0x50d99381dbab82e0', 'Jazmin Rosales Makeup & Hair Studio', '+523228896912', '+523228896912', '
Plutarco Elías Calles 262, 48291 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6974757, -105.2453301,
  'https://lh3.googleusercontent.com/p/AF1QipOfnIR3TbFATCHspkIASHBqhAgUprr_EPHdz_s2=w408-h655-k-no', 5.0, NULL, NULL,
  '{cabello,maquillaje}', NULL, 'https://www.facebook.com/share/14NN41UKbzz/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145ca2393f539:0x4dc5c859643fba09', 'Jeniffer Lopez Beauty Artist Puerto Vallarta', '+523223018702', '+523223018702', '
Río Potomac 117, Fovissste 100, Col. Fluvial, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6451547, -105.2215756,
  'https://lh3.googleusercontent.com/p/AF1QipMQrJVNqMkFGH1VZQussF1O45ur8xrGNuB615Fu=w426-h240-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.facebook.com/maquillistanoviasyxv', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145706a32b317:0x8cb6e5371f46001b', 'Joel Salón', '+523222228722', '+523222228722', '
Boulevard Francisco Medina Ascencio 2053, Plaza Pelícanos Local 5, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6371359, -105.2324474,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqii7QHDp_f_QrGA4KoGqreIdsS7fucWpPV0VGTgjPcPgzV1czfUuopjnfKxtiJxqUdhwshN7P1we1hw3Qm6BpVZK9bU770SAm8Td1iywavnJXUdrVxOadsvO5lTr9Q50wAobzrww=w408-h544-k-no', 4.5, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fb0741c861d:0x63599f5eeba0aa01', 'Johanna Videa Beauty Studio', '+529212659266', '+529212659266', '
Lázaro Cárdenas 315, entre Aldama y Josefa ortiz de Domínguez, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6524143, -105.2144046,
  'https://lh3.googleusercontent.com/p/AF1QipPzVlVsH-zyQDvKYMOTdkM9BLqp63DJhGXapMYK=w408-h504-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145e7b125ec89:0x1bef19907b8a8d25', 'Kahlo Salón', '+523221056611', '+523221056611', '
C. Cardenal 113, Fovissste 96, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6443409, -105.2195816,
  'https://lh3.googleusercontent.com/p/AF1QipP8R-PGLitbyMbp1JZsAhJJW32aR2uOzyrQ45H-=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421479517077c59:0x2df89c6064e844db', 'Karen Palomera Makeup & Nails', '+523222944457', '+523222944457', '
Valle Grande 154, Valle Dorado, 63735 Mezcales, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7160678, -105.2719088,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoAy-IbIWcjIqMYxTY9fJTDjXSOD9YqYOGxDfCZkGhkSrfwDjOHeQVq4H5wT_RpQOTZFiCu9IBc8FmNe-45FFJDFVRMP5RdwdBeY1MEO-0sKgh-Rtr-L-Hu1yZw8xqFNqgYfgw1KIxg07M=w408-h544-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{maquillaje,uñas}', NULL, 'http://www.facebook.com/karenpalomeramakeup', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214513d474c52b:0xc2137f292a9cfbd6', 'Karina Alvarado Makeup', '+523223696610', '+523223696610', '
Av. Francisco Medina Ascencio 2036-local 2 planta alta, Díaz Ordaz, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6363972, -105.2314086,
  'https://lh3.googleusercontent.com/p/AF1QipN_vqw70irEx3NKIo2QhD6QEqavqbnhibZBEw=w408-h541-k-no', 5.0, NULL, 'Centro de estética',
  '{maquillaje}', NULL, 'https://www.karinaalvaradomakeup.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214571b5272af9:0x42e003771ffd3032', 'Karina Cosméticos', '+523223099934', '+523223099934', '
Hidalgo 166-E, Leandro Valle, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.651333, -105.2196125,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepFTJiW4jLP_y6JEexWySbYyeO1DQY0uuG1SWf5XZML2vOqg0dm21GF9v-ZOlL1_LYsZnyWclArcaDKEnQ3QIL1qf7VFlixQp31lwMRR4kXplhkAn-X9W65sPVx-ZBkIiIOS1Qj=w408-h306-k-no', 4.3, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, 'http://karinacosmeticos.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421472420192fdd:0xd3981ac8bc97c499', 'KathLashes', '+523221510004', '+523221510004', '
Valle de Rosario 178c, Valle Dorado, 63735 Mezcales, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7155651, -105.2714448,
  'https://lh3.googleusercontent.com/p/AF1QipOFtwtbAjrv_fNxY8owlJO2JS8gFHS3Bmg-36I9=w408-h408-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.kathlashes.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214544cfa4877f:0xa4e45db755a7036d', 'Kireth Spa & Lounge Bar - The Best Vallarta Massage', '+523222222210', '+523222222210', '
Av México 1081, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6160548, -105.2318484,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqIeSWptF2v9FqyEvNdG_a0K_wHKBUUmehqcJpVIciLT8P2lR-b01fdrqraiBJ__Qcxg_r4c59pR103jgW1l7QvcRmLU-jbC3n7kpGpEfh2gE1cacuUeFS8zpObU7wLz7wUIz8XJA=w408-h306-k-no', 4.5, NULL, 'Bar',
  '{cuerpo_spa}', NULL, 'https://www.facebook.com/profile.php?id=61555217485630', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7e10ec0e39:0xec91e298a5e5475f', 'Kiss Cosmetics', '+523227798387', '+523227798387', '
20 de Noviembre 201, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6530342, -105.2186389,
  '//lh6.googleusercontent.com/R5B9PNFQr69434f8y0cDJFr3Qff78W3rFGNFv_XLku-6oFjPi5xpbYNBtJp6OHZ5CQ=w408-h726-k-no', 5.0, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7efc5637bb:0xa0f8572d2347aa23', 'Kytzia Salón De Belleza', '+523221217493', '+523221217493', '
kytzia salon de belleza, Aldama 136, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6518436, -105.215837,
  'https://lh3.googleusercontent.com/p/AF1QipMD6c3MJzkZrLWd1ko3pOtjEcZ_8d8a0HzSH3Yf=w408-h306-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145cb92f273a7:0x1a0732772abb2dd7', 'L''ARTISTE SALON', '+523223282900', '+523223282900', '
Blvd. Francisco Medina Ascencio 1989 Plaza Villas Vallarta local F-18, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6343124, -105.2310738,
  'https://lh3.googleusercontent.com/p/AF1QipPddScY8PZ0s-4egkbDnB3BZYg2F9Flx5xSrRHo=w648-h240-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.lartistesalon.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457734bcd789:0xbd31c1c8a119d6b4', 'L''oréal Professionnel', '+523222251276', '+523222251276', '
Av Los Tules 178, Díaz Ordaz, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6411894, -105.2329626,
  'https://lh3.googleusercontent.com/p/AF1QipO_DNjsIgQNjKpyaBySwnfkWYePdjJ7sxhKNtf4=w408-h544-k-no', 4.0, NULL, 'Tienda de productos de belleza',
  '{cabello}', NULL, 'http://www.lorealprofessionnel.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214548fdbf0419:0xa7cbecec8243428a', 'LASHES STUDIO MP', '+523221001495', '+523221001495', '
Supermanzana 6A, Villas Río, 48313 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6516951, -105.2244985,
  'https://lh3.googleusercontent.com/p/AF1QipP-fIv5mv51ke0DPGzqbmZVVBdtZL7SWAoaOQQ8=w445-h240-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.facebook.com/profile.php?id=100091199464817', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c5d0b3a5f:0x4e371cf1f5329ab', 'LATORRE HAIR STUDIO', '+523226882012', '+523226882012', '
Lázaro Cárdenas 279, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6037097, -105.2354764,
  'https://lh3.googleusercontent.com/p/AF1QipNUtLx2oFMx5RAaAotgKLtpi_GDVTGa5I71iw6b=w408-h725-k-no', 4.8, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c673334e7:0xd8aa2a5d561bdc19', 'La Barbería PV Zona Romántica', '+523226885551', '+523226885551', '
5 de Febrero 260a, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6050711, -105.2361459,
  'https://lh3.googleusercontent.com/p/AF1QipN6g74Io1wPM9KcAUJ1PQJo2aZ6Li2GKHjB-NUe=w408-h906-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, 'http://www.labarberiapv.shop/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455d6ce06c4d:0xa38649ca8d279c81', 'La Barbería PV estadio', '+523222233991', '+523222233991', '
Brazilia, Colombia 272-A, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6226273, -105.2291857,
  'https://lh3.googleusercontent.com/p/AF1QipPPv9A4zoSmhgFsGcrsjSGwZjJ8q4Yr9Jm7_lt4=w427-h240-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, 'https://facebook.com/labarberiapvestadio/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145453bb21319:0x61bacedc709e75a1', 'La Barbería PV/ La Barbería Puerto Vallarta', '+523222222108', '+523222222108', '
C. 31 de Octubre 135, Centro, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6141335, -105.2320786,
  'https://lh3.googleusercontent.com/p/AF1QipM5CkEZqDa9IRozuJrGH7sGdDGVz0_-G3TKIBo2=w426-h240-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fd819245e7f:0x4e4795087c8f6168', 'La Nuit Nail Studio', '+523223833722', '+523223833722', '
C. Puerto de Acapulco 180, Los Ramblases, 48345 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6286652, -105.2091859,
  'https://lh3.googleusercontent.com/p/AF1QipNt1rjJtaZgNsgdhf2J1D6Lwdavcajssb0i60kB=w426-h240-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7ff922cde9:0xdb7859fc4a58dc88', 'La Urbana Barbería Clásica', '+523222255585', '+523222255585', '
Av. Francisco Villa 1526 Local C-13, Macroplaza, Los Sauces, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6452389, -105.2180396,
  'https://lh3.googleusercontent.com/p/AF1QipOqaws2FuD6J9211tYU6gIa0urROpdnVbIII16c=w408-h419-k-no', 3.7, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454bda1d435b:0x6c68fdf054049e72', 'Lashes Kenia Ruiz - Extensiones de pestañas', '+523222131336', '+523222131336', '
Pedro Gutierrez 102, Costa Coral, 63735 Las Jarretaderas, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6884783, -105.2780939,
  'https://lh3.googleusercontent.com/p/AF1QipOP8f6f8qseRj5HN_jXKiyLfcug2Hqd0Z_NP6Y9=w408-h545-k-no', 4.8, NULL, NULL,
  '{pestañas_cejas}', NULL, 'http://www.lasheskeniaruizcom.wordpress.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214570e8944947:0x76db4555aeb7bedf', 'Last King The Barber Shop & Tatto', '+523222258607', '+523222258607', '
Av. Francisco Medina Ascencio, Díaz Ordaz, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6393697, -105.2333013,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweo2rRU_t4L__h-KdjO_CF1tvVxnx9QQvOcHacAkFRD_rpWcC0qrGMF0MBZYvJrSqlZfLabIiBnVwLxVdhCmsaER4nyJg4QGGJxZ2IEelpfosVg9qIS0VevJUUDeolc5vJNRodU=w408-h544-k-no', 4.5, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214692ffb1dcdf:0xd827abe7064670f7', 'Le Spa', '+523221132838', '+523221132838', '
Av Mexico 570-Altos, 63735 Nuevo Nayarit, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6996284, -105.2760132,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepX2PKY3QCpVpUpCZtc74ldiwAWPuwK8-vqk-gIx18VngObG-rV9fKuZkt3rFD_yTmpKGSmGfs1488JUUCZnOBqZ6YqGtlQcOhBdkd7Q__8hL_Y5trTuYPOYy8eqOU7ubTfj79q=w408-h544-k-no', 4.9, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'http://www.lespa.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214523368df0f3:0x62f2c2a5d348ae51', 'Lehua Nails Studio', '+523322921929', '+523322921929', '
Av. Francisco Villa 515, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6313447, -105.2266267,
  'https://lh3.googleusercontent.com/p/AF1QipNslPgVRCf3rHt47ZD6pn0aP90lAgs0t6uF1fAn=w408-h408-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://wa.me/message/BMHBNBI2MV23L1', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452963debe05:0x87ba498469206013', 'Lila Nails Salón', '+523222454836', '+523222454836', '
C. Milán 255, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6356945, -105.2279943,
  'https://lh3.googleusercontent.com/p/AF1QipPt3mgwST7DPAXYZm7Q7tKJc5WV0il96NoVZ4uI=w408-h544-k-no', 4.3, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.instagram.com/lilanailsandgallery/profilecard/?igsh=MW5pOXJzNXhjamZz', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fc615dc96ef:0x6772d574ccfbefae', 'Liliana Landeros Makeup Artist', '+523222031957', '+523222031957', '
Cto. Lipizzano 111-23, Fracc. Hipodromo, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6696759, -105.2169307,
  'https://lh3.googleusercontent.com/p/AF1QipP8VhGUzPD20f8Y_cLvT3LVgoM5Ir5p87VX2OQA=w408-h255-k-no', 5.0, NULL, 'Make-up artist',
  '{maquillaje}', NULL, 'https://lililanderosmakeup.wordpress.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214561eddb5e75:0xdea8e31fea317b39', 'Lissy García', '+523221096901', '+523221096901', '
Fco. Zarco 105, Palo Seco, 48320 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6297687, -105.2206159,
  '//lh5.googleusercontent.com/O-Oof3iO0FEDvWc5V-hYN0NH1dGsltF5BTbBuENEo2c_k8XQFDCMJyXz6D0oJ6A=w427-h240-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454eeb79769f:0x7cdbb0454381411a', 'Lotus Spa', '+523226882224', '+523226882224', '
Morelos 172, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6074953, -105.2365561,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepCm2kSalj_pLHhDoOZL3xbBiwXMm6I8sCwTwT6qYf3Qp8Ekxv99UusQEIMy8M8qreFfZ89RmRSy4wij4gqPkT9EdzYG1Y7fRhfuOY-sg3lu40bXgzOQnHNQSly2Re2lWK7nALT=w408-h544-k-no', 4.3, NULL, 'Balneario',
  '{cuerpo_spa}', NULL, 'https://www.facebook.com/SOUL-TWIN-SPA-103432715493371', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421451beaf1f619:0xd28798d816df050d', 'Lou Lashes PV', '+523221986669', '+523221986669', '
Ecuador, Ávila Camacho 1737, Lázaro Cárdenas, 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6266611, -105.2260668,
  'https://lh3.googleusercontent.com/p/AF1QipPyL7rzvg-ffNXyzf_IjUTSM7MW33aayeK9WoIY=w408-h544-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://instagram.com/lou_lashespv?igshid=YmMyMTA2M2Y=', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0xd482477c716e8f7:0xc2f42c617c724961', 'Luisabella beauty pv', '+523221600982', '+523221600982', '
Morelia 123-3, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6312131, -105.2278936,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwep9nEGXG_376cCx_SYjH-ZOXOZhIvmi7MtIGjn95_jQVNETtbZ-FeqGB3tOH9nT5Xscogzxs1zpNoUJqGWmQ6Aiky9EelFYJsvXFYx98AOoXLN6rAJGDRc5dSfHSa5lEvMEamI1Y0rma2E=w408-h455-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7ffa1d45c5:0xa2c08c12fcba972a', 'Lupita Rayo Studio Belleza Con Estilo', '+523221328163', '+523221328163', '
C. Pavo Real 205-Planta baja, Las Aralias, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6397886, -105.2149843,
  'https://lh3.googleusercontent.com/p/AF1QipNdv3wjfSnZ20KQsapvKp628kWvlAlpEcuyeAzu=w408-h725-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://instagram.com/rayolupita_?igshid=YmMyMTA2M2Y=', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214575c29b5617:0x5007553311b63d09', 'MAC Cosmetics Puerto Vallarta', '+523222168881', '+523222168881', '
Av. Francisco Medina Ascencio 2333, Zona Hotelera, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6449901, -105.2378728,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepVS8mk0gqNQlVBKO3BSMD4TvNRxEdnXOCEydTBZLoYSgFfuk_xnYTF8wzmSLkQKfv9PS_Vo77SKn5lMdBHjLQoPz9dvylc803sBzcaFhg2xn7Ty0TsctHuYQpUAbIMn3JtVy4=w408-h725-k-no', 4.3, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, 'http://www.maccosmetics.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f73d5877625:0x130de6efb9530e0f', 'MAJ Salón', '+523223215164', '+523223215164', '
Cándido Aguilar 537 A, las Juntas, 48291 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7027659, -105.2372516,
  'https://lh3.googleusercontent.com/p/AF1QipOvzkFI0DwqjVjT48nf1Hf3yIP9RRopDq2lq5jH=w408-h544-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://facebook.com/MAJSALON', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145bf350f6d07:0x561d16d0828f8027', 'MAKEUP VALLARTA WEDDINGS', '+523221830358', '+523221830358', '
AV DE LAS PALMAS 3-5 EDI PLAZA DEP 13 LOC 13. INT E, Blvrd Riviera Nayarit, 63735 Nuevo Vallarta, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7080759, -105.2931319,
  'https://lh3.googleusercontent.com/p/AF1QipN9NsKbFePUuDF14LgjBOder2xzA66uvUvfOQg5=w426-h240-k-no', 4.9, NULL, NULL,
  '{maquillaje}', NULL, 'https://www.makeupvallarta.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145679e285917:0xf881c315cab98fff', 'MM Company Barber Shop Tattoo Piercing Zona Romantica', '+523223802935', '+523223802935', '
Ignacio L. Vallarta 189, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6042737, -105.2361482,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweou-kpBMrlxfXhhDlBheaa2U2i0gzOJGMdoRxlAKhB-RF5exhK9OTFPZSAPWSNXRjGlx3Uz5VrrJtDVqc12iXvIvABjg5-rgYz-zfr6DPqlXeH-C1Ndw7SMSzMULqF6d2-6HvZW5Q=w408-h510-k-no', 4.9, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, 'http://mmcompany.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452ff413d611:0x49136b3499e8b5e1', 'MM Company Barbería Tatuajes Piercings Suc Malecón', '+523221266836', '+523221266836', '
Jesús Langarica 174, 5 de Diciembre, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6145948, -105.2320611,
  'https://lh3.googleusercontent.com/p/AF1QipOcmuF0zgvu2XpLmBgcqQy1jrPMXp6xyVKN-4LI=w425-h240-k-no', 4.9, NULL, 'Barbería',
  '{cabello}', NULL, 'http://mmcompany.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214576d72cb7df:0x19042fae3d26de1e', 'Maash nails', '+523224039455', '+523224039455', '
Francisca Rodríguez 256, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6011742, -105.2353205,
  'https://lh3.googleusercontent.com/p/AF1QipOzGyu5LV0rHV5JYv0aNjAnfcqEnov2qAfd5iBQ=w408-h306-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147d00340b26d:0x9ddb66dcf5662641', 'Magie Rose Nuevo Vallarta', '+523223025121', '+523223025121', '
Plaza Dorada, Valle de México 2-local 16 y 17, Valle Dorado, 63735 Mezcales, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7146037, -105.2757966,
  'https://lh3.googleusercontent.com/p/AF1QipNEsK2Ydc7oDXJC8QijDl4IIpWg4Ag0EDEMQ_QX=w408-h544-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145f41663ab71:0x224a7baa2011d4d0', 'Maiavé Spa', '+523222260424', '+523222260424', '
Blvd. Francisco Medina Ascencio No. 999, Zona Hotelera, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6264929, -105.2310912,
  'https://lh3.googleusercontent.com/p/AF1QipNGOKRuOXcPOyhcLjGuLw_rEN0apZE6XB7nWSH5=w408-h281-k-no', 4.9, NULL, 'Spa y gimnasio',
  '{cuerpo_spa}', NULL, 'http://maiavespa.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fabc08adf55:0x87ad7f144636aec2', 'Malva spa Vallarta', '+523221467532', '+523221467532', '
Tucan 144, Las Aralias, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6392196, -105.2189074,
  'https://lh3.googleusercontent.com/p/AF1QipP_RDCqSc7tv_L1FyBeEvE6En1vl9livzLgj8R2=w408-h452-k-no', 4.8, NULL, 'Spa',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421459f5a32aacb:0x2bb66646173742f1', 'Mantras Spa', '+523221841931', '+523221841931', '
Av. de las Garzas, Zona Hotelera, Zona Hotelera Nte., 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6508599, -105.2423377,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweprlgJQi7xap9JVrbtEp5jbDAjz4NcUTQLKe8t5sV-FWjvWygC2B5hV3uA2ncC_K8PFopaB6YHsueEwq_HTFUdnXRUmK6Xfje0LzcLm6HrB6uDt_RtVdPXErV2kr2CPtda16sKNow=w408-h408-k-no', 4.3, NULL, 'Spa',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fa531e9b02b:0x574a97584dc55348', 'Maquillaje y peinado en Puerto Vallarta - Osiris Manzo Makeup Studio', '+523222354718', '+523222354718', '
C. Exiquio Corona 513, La Floresta, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6657184, -105.2162619,
  'https://lh3.googleusercontent.com/p/AF1QipOkgBCHLRM54qtF4i6teqiuWRy0Vi7oBwmEUjg=w408-h271-k-no', 5.0, NULL, 'Centro de estética',
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214900716338a7:0x71ea22065791f54d', 'Marea Beauty Ixtapa', '+523221826376', '+523221826376', '
Faisán 102A, Los Tamarindos, 48280 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7171427, -105.2139464,
  'https://lh3.googleusercontent.com/p/AF1QipMbxoXKXz-9A8Ce9VwCEZ6F7y79qOH62zxkUvGZ=w408-h544-k-no', 4.2, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421494fd2d4b76f:0x25916f18dd6dfc72', 'Maria Guerrero Makeup Studio', '+523222298937', '+523222298937', '
C. Jalisco 378, paseos universidad, 48280 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7102235, -105.2152475,
  'https://lh3.googleusercontent.com/p/AF1QipONQZbQswQj9S0dPMzfJoA5ShvcPrqnRnzTz0yq=w408-h544-k-no', NULL, NULL, 'Centro de estética',
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145fb5d6601d7:0xc22e8fe9e573fc72', 'Marina Salón Spa', '+523222213694', '+523222213694', '
Paseo de la Marina Sur 159, Las Palmas II, Local 13 y 14, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6629133, -105.2542901,
  'https://lh3.googleusercontent.com/p/AF1QipPg4pAI4kfmfMLUrypV-BzPFYk4ZzLbZVErvL7q=w408-h306-k-no', 4.7, NULL, 'Esteticista facial',
  '{cuerpo_spa}', NULL, 'http://marinasalonspa.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b987e2c4c5:0x989dbf4dd49e0b11', 'Masajes Spa Venus Sunshine', '+523222091330', '+523222091330', '
Paseo de la Marina y Ancla St., Local 22 Palmas II, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.662634, -105.252386,
  'https://lh3.googleusercontent.com/p/AF1QipOo2qI9WWliH5_B5U_LwnZN3uIzLVLWvEkJqL0_=w408-h306-k-no', 4.7, NULL, 'Balneario',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f4a7b493cff:0x956cf6ea31d9dd17', 'Mayam Beauty studio', '+523223830302', '+523223830302', '
Av. Arboledas 231-8, Bobadilla, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.657071, -105.223852,
  'https://lh3.googleusercontent.com/p/AF1QipN2JBXR14kqyFnjZSkMAATzJY9BNh4QfrnJd3io=w408-h508-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b8b2c05aa1:0x5f62f285621e984c', 'MedSpa Vallarta', '+523222210080', '+523222210080', '
Plaza Neptuno, C. Popa Local D1, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6678864, -105.2488195,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepcRovbiCKfr3C9YXjB1wS64dpwq6cmu7ezJk4tO6LOpTllszBVFOEQgeFKgKbtl6FxmMHxsU3vTnP4G08D8yHK_z5yjnCuhYPfU0AHwh3-f1ohxmYEJ362hziAk0Hx5u8fhcQj=w408-h544-k-no', 4.7, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'http://www.medspa.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454b580d26b3:0x51271adda667340d', 'Metamorfosis Day Spa', '+523222148299', '+523222148299', '
Francisca Rodríguez 159, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6009626, -105.2373999,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer7ocd8pzNNOgUjdzLPVfH1utv1Q7QaY-b2wBy9DCl0h2bZxt9lcWUmr8fhsL3Y_9ZcqyICsLJPTjLnHD-u8ltcdcKtUxbpoDVeqmTA7H55UcwJC2ZFdcDw5I90KLOChIL1PS2QPQ=w408-h544-k-no', 4.9, NULL, NULL,
  '{cuerpo_spa,facial}', NULL, 'https://metamorfosisdayspa.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7e5ec465e7:0x3251f083bc5151f5', 'Mi estilo salón peluquería', '+523223320749', '+523223320749', '
20 de Noviembre 267, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.652423, -105.216798,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer33FtTbzh6tJVcAAKsyvTWdushOuQiNjbtDkisOXM3BITP6OJ53CWDl9u1SBGVFDwuB7lFJFzofQ2ao5zqVApSOFxky5banu4mCkJyC1SsuGViCttrlHW9QvohkgEbPkLS9z8=w408-h545-k-no', 4.2, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/Mi-estilo-100401838166231', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454b662513eb:0x6dac0cc91002d6f6', 'Microblading Vallarta by Gigi Yarden', '+523221344697', '+523221344697', '
Francia 203, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.637283, -105.2275729,
  'https://lh3.googleusercontent.com/p/AF1QipMaOkH6NynnU8YM29hwKK76Pw4zSj08E7_ZoCfT=w630-h240-k-no', 5.0, NULL, 'Tienda de accesorios de moda',
  '{cabello}', NULL, 'http://www.gigiyarden.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145bf62ea18e7:0xf8746f72d677f99', 'Mikova Nail Bar', '+523222937827', '+523222937827', '
C. Prisciliano Sánchez 519, Las Moras, Villa del Sol, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6556491, -105.2317307,
  'https://lh3.googleusercontent.com/p/AF1QipPs1C11EkQF_np6b3fvR47vuXyhMqzuB0JUmB_C=w408-h408-k-no', 3.8, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.facebook.com/Mikovanailbar', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214529e46ea557:0xb27ef81ee0b988e8', 'Monchell SPA', '+523221095840', '+523221095840', '
Portal Calimaya 542, Los Portales, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6630169, -105.2272486,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweruhOW_6Q4ZHdNmyP6ELUEijrlGjO_wY_BBejhe9IOnbVUsZqx7oJzZUniQp3DH5GsiD1ILWhzFw8R5z-zmr9_2XBbAQEDHatftggup3Kh2YWHhNLW6CW4yeABPWqkeVycSDnq5X5G6YYuz=w408-h544-k-no', 4.9, NULL, 'Spa',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421458059cf9429:0xaa8130a3bc643e4d', 'Monica Covarrubias Makeup Artist', '+523223072749', '+523223072749', '
Plaza Marina, Local G-13, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6712872, -105.251292,
  'https://lh3.googleusercontent.com/p/AF1QipOBdM9sTbLccRnIMZRNMpr_SnTWraewAa0d6hXQ=w408-h451-k-no', 5.0, NULL, 'Centro de estética',
  '{maquillaje}', NULL, 'https://www.facebook.com/monicacovarrubiasmakeup', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7e64c69c41:0x992ddff6f53a4acf', 'Monik', '+523222240728', '+523222240728', '
Lázaro Cárdenas 243-Int. A, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6533201, -105.2169798,
  '//lh5.googleusercontent.com/7HJjPDHVWBTWIMxtQW7RXC-itUN2ZpdpdOMZI7U-uwHb-z5QlRwTNLXSlgAJh7k=w427-h240-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f6855a09bdd:0xc15eb7fd4d17043f', 'Monserrath Gonzalez Makeup', '+523221404715', '+523221404715', '
Guatemala 436, Coapinole, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6592277, -105.2051218,
  'https://lh3.googleusercontent.com/p/AF1QipNejDqwwkHwaUQhq3_6s-FRSm65oqDTTO6VGSB2=w408-h725-k-no', 5.0, NULL, NULL,
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f50552c314f:0x567060fc8781ff7f', 'Montse Guardado Makeup Estudio', '+523221567731', '+523221567731', '
La Capilla 175, Santa María, 48325 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6287018, -105.2197436,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqFz-nbAT2RrfnfopS66kECBTjdNIDgPpHMc8OJzz4p2LHstpNKekIbsyU0wQ8PFLP4X8yh8AKjp6E6ypWqmGmf-p_BVY1ijJ4yyU9Pqo1J4g2ymr1zkcaj5_37d9W7lOQsAxqo=w408-h544-k-no', 5.0, NULL, 'Tienda de belleza y salud',
  '{maquillaje}', NULL, 'https://montsemakeup.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455bb2ed7dc5:0xb59491ec75c36f15', 'Morales Barbershop', '+523222117184', '+523222117184', '
Venustiano Carranza 452-A Col, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.603706, -105.231619,
  'https://lh3.googleusercontent.com/p/AF1QipPpBWP6rST54W2j6rXjbZyBWy8O7czywGCsV608=w408-h544-k-no', 5.0, NULL, 'Barbería',
  '{cabello}', NULL, 'https://www.facebook.com/Morales-BarberShop-100956531600694', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214522a60a2e9f:0x12bb4fce4820ada7', 'Musa Studio PV', '+523224455811', '+523224455811', '
J. Jesús, C. González Gallo 75-int.37, Vida Vallarta, 48318 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6468217, -105.2198665,
  'https://lh3.googleusercontent.com/p/AF1QipMtNc8fEqu-hmE-XSo643ShpURt1gUdUtvC0lhl=w408-h354-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457a99d7e2d3:0x1fbb9b757e866d2d', 'Nails Salón & Hair Studio', '+523221205563', '+523221205563', '
C. Roma 163, Díaz Ordaz, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6376722, -105.2304762,
  'https://lh3.googleusercontent.com/p/AF1QipPyBA_w67XCJIoQsLV1Z02O8FewtweC079VwkMu=w408-h468-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello,uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421450eb3c9eb1d:0x581204b76fe38944', 'Natividad Melchor NM Beauty salón& salón', '+523222321821', '+523222321821', '
Plaza centro city, C. Prisciliano Sánchez 519-local 2, Las Moras, Villa del Sol, 48313 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6552632, -105.2311859,
  'https://lh3.googleusercontent.com/p/AF1QipPlG_Zr1pDpyR707KzxB9LC_HqPPL6ksCYgXbyp=w408-h543-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145041dbd4cd3:0x717d01c0d94ef1c1', 'Nessa Beauty PV', '+523221391200', '+523221391200', '
Av Palmares 611-20, Villas Universidad, 45290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6799272, -105.2155116,
  'https://lh3.googleusercontent.com/p/AF1QipPdMU8YyOPArkEGhd02XfQtLAcj1pXLuPHS4py_=w408-h306-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145649ac5bbad:0x83703a5ce30f6f7b', 'New Look - Nails & Beauty Salon', '+523222250795', '+523222250795', '
Rafael Osuna 157-Int. A, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6338008, -105.2259455,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerTXFK58sfAjwo6Z3HwufzkXOHXCqJRmvBMTWguvLmdzbfTDEl8UWIkYyoWK1oBoeEBv2dgDQ7xMQAtjxvEPBLd0TADYeuuyDWxVbWQbYg3GaJGInGsZ7nDov4Be7s3xeFYtXCO=w408-h408-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello,uñas}', NULL, 'https://www.facebook.com/VallartaNewlook/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842148a3d9fcaa37:0x4f34fad9902d57fb', 'Neyma Estética Unisex', '+523222812972', '+523222812972', '
Pelícano 227, Los Tamarindos, 48280 Ixtapa, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7146748, -105.2132954,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqPhfJ5DguQUPhCx4DMWV-807qKQ890Q1ZNs9dGFwdNOcEFSmNfnPEEMqIATPTKLAQc-Gzsp4OrXAANcXmFWSZatB5-ameI4f9iDeTNyeXM32x6gb6ldgs49Q6C3w5jZWo58xpGew=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452db568e871:0xa8f80a36a8d45976', 'Nicky Nails', '+523222824898', '+523222824898', '
Blvd. Francisco Medina Ascencio 1768-local D, Olímpica, 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6291018, -105.229073,
  'https://lh3.googleusercontent.com/p/AF1QipN-vM_QEbHmJwDI7F8cC1RvRomstNhOIUuRRfgz=w408-h272-k-no', 4.9, NULL, 'Centro de estética',
  '{uñas}', NULL, 'https://instagram.com/nickynails.pv?igshid=7ycbdy0mmyvv2', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c7642af21:0xc2e9afc4a5759910', 'Nicté Spa & Massage', '+523221010148', '+523221010148', '
Plaza Caracol local #20 planta alta, Av. Francisco Medina Ascencio, Los Tules, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.640821, -105.2330613,
  'https://lh3.googleusercontent.com/p/AF1QipNWZ65gDve_rZANYmi-51soHIl6anDEJFTIwqS0=w408-h438-k-no', 4.6, NULL, 'Spa',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214672dcde4bb1:0x7206397505c2dd79', 'Nuevo Look Estética', '+523221116977', '+523221116977', '
Francisco I. Madero s/n Las Juntas, 48291 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7017094, -105.2441501,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwequQ6r3TcwaXZZbx3V-QOba1VZjSzP7cy5UWJFiH-Q8-LrBpFxWKUGZv_khqZYeVSajBjLL965LDqbYcVaQ5YmHH7Jc53tz-XpuVgExdpEdgGunVpgZUmLOKhWY7AC7oJRSTMpI=w868-h240-k-no', 4.4, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fad0411a727:0x93cecbe0273d4e94', 'Núa Nail Studio', '+523223075576', '+523223075576', '
C. Independencia 291, Colonia el, Centro Pitillal, 48290 mexico, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6514218, -105.2163959,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweo-DHvkDUPLDY7WA8jQxKntUKhm5IfmEUfGxH9VGd8OAF0-Ln_ZlGfkUc2X9HuBq-UQwapyGDtrcj5ULPGeJ-2DOWR2CzlrZFZkbyvF6Io-ylFOpQtdMo5a-jn3eSZokkTpK1n8lyR2LUrO=w408-h544-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.instagram.com/nailstudionua/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145c4d2ddb825:0x9d08f6ba1a60143e', 'Oh La La Salon', '+523221409462', '+523221409462', '
Sta. Teresita 129-D2, Valentín Gómez Farias, 48320 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6302277, -105.2197316,
  'https://lh3.googleusercontent.com/p/AF1QipMbT3aYWUvq7SYvt_HW97ozZKV5CCRTg4saAZ_N=w425-h240-k-no', 4.3, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/ohlalasalonpv/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b0ad3ab0b1:0xaa5cc1c6663b60e1', 'Ohtli Spa', '+523222260076', '+523222260076', '
Av Paseo de la Marina Nte 435, Marina Vallarta, 48354 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6620827, -105.2559155,
  'https://lh3.googleusercontent.com/p/AF1QipNNNIkxSWSSdnsbTPVIbnLS5FwmSz3iUhZF0yNE=w408-h272-k-no', 4.4, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'https://www.marriott.com/spas/pvrmx-casamagna-marriott-puerto-vallarta-resort-and-spa/ohtli-spa/5014783/home-page.mi?scid=f2ae0541-1279-4f24-b197-a979c79310b0', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214ffc1f2b36f1:0xd549f25399f15e08', 'Ojos Azules Nailcare | Puerto Vallarta', '+523221465691', '+523221465691', '
Blvd. Francisco Medina Ascencio 1939, Zona Hotelera, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6321406, -105.2294857,
  'https://lh3.googleusercontent.com/p/AF1QipODotJphuqNys0sF3o7T6iKRCgPKVphIp0e9yBE=w408-h542-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.instagram.com/ojosazules.vallarta/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214534e8c3607f:0x379cd289145514b3', 'Oscar Reyna Salón', '+523223202841', '+523223202841', '
Av. de los Grandes Lagos 303-Loc. 30, Fluvial Vallarta, 48313 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6543072, -105.2255211,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerUrXlb4-FOgu4KHv-rQczch4sPRhCIz_nEIsQ9GnfieQavkwKyHrEle10radfExdj2RFVEndKE9bL8gLitrLmcU0RqO4FKIv7XcHjckhScXa-5PCFTd37nWGrFkyDz2o6LRGFGPw=w408-h544-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457bdc895847:0x697addca66f9ea29', 'PINKY BEE', '+523221667737', '+523221667737', '
Av Fluvial Vallarta 201-Int. C, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6410582, -105.2271015,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoFGe5cAPId-kvC3wHI2fDH56RoZQN1tc0roJ0lCN5CNV7J-EbW8tCbTxE8DxX7dYGQKcT0iuAiddXk53V1_SJLugEkVDQ_kYzNZLfvaIL_oaHSfEjAUcJlGIQ1kHk5CfV9xNVu=w408-h839-k-no', 4.4, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.facebook.com/pinkybeespa', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454d1c9c363b:0xce802c8bf49fe6f3', 'PV Spa Masajes Barbería', '+523221711403', '+523221711403', '
Insurgentes 386, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6024321, -105.2337824,
  'https://lh3.googleusercontent.com/p/AF1QipO_eSSYM6QLpqUN0nsyacE-4YkSaBct7v_OFwg2=w408-h724-k-no', 4.8, NULL, 'Barbería',
  '{cabello,cuerpo_spa}', NULL, 'https://pvspazr.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214525915a9821:0xcfed0b39870022b7', 'Palme', '+523223536668', '+523223536668', '
Niza 189 A, Díaz Ordaz, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.637934, -105.2293199,
  'https://lh3.googleusercontent.com/p/AF1QipPA_6F4iAEKWs-nO41pPqWrN8A2989XxsgHxqCG=w425-h240-k-no', 4.9, NULL, 'Salón de manicura y pedicura',
  '{cabello}', NULL, 'https://instagram.com/palme.beautyroom?igshid=YmMyMTA2M2Y=', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842146857af1464f:0xde0a3b4c215416d6', 'Paloma García Salon', '+523222971827', '+523222971827', '
Blvrd de Nayarit 810, 63734 Nuevo Vallarta, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7004556, -105.2755682,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepd9bZgDV_Yzlfa_606o-f6FyxYW4WEVanOC13oa6FzqXzP6ZOVBebxMewgCvdMQCnMiCC-8aMEXXhHc-6CXeLr5YUqV3PfYK_MRPxMoF3Yb2V7Dqg8UsPJardRhJP1wj3wxzqc4A=w408-h544-k-no', 4.1, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://es-es.facebook.com/pgsalon', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147775968cf6b:0xe2bbec1fc43f3b9b', 'Paloma Monteon Makeup&Beautybar', '+523221117314', '+523221117314', '
Revolución 399-A, 48291 Las Juntas, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6983588, -105.2438716,
  'https://lh3.googleusercontent.com/p/AF1QipPHTCg6wuVWitmRiYkU6vqZOfowP6dtQn48FY_b=w427-h240-k-no', 5.0, NULL, 'Centro de estética',
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842146befc1ea8e7:0x9e4160bc47324a9d', 'Patty Spa Riviera Suc. Av. Las Palmas (next to plaza 3.14)', '+523221563245', '+523221563245', '
Paseo de Las Palmas a un lado de la plaza 3.14, 63735 Nuevo Vallarta, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7076628, -105.2931352,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepRAcXq7EoIyziRlzggO4nccwqh-ylJlVXu_QM2JtkdMOfyPRKBoOqfNc1p5Tqplrb0-vCMixEJ3tu5__OFXWVWMkDTgu-dePqJ3LDQvqVXqstRQty7oI0yX5XfeM_McflFzCXeRw=w426-h240-k-no', 4.4, NULL, 'Spa de día',
  '{cuerpo_spa}', NULL, 'https://pattyspariviera.com/?fbclid=PAZXh0bgNhZW0CMTEAAabaC9PVzJiwxxb4pHUm_yvWZCGhWtLYNzHckA9sZFry0nh3SMpGA0lyStM_aem_j6wGReiCpI3ZTzsbaGRyZA', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c6f244773:0xfac111914e9abff4', 'Pedicure y manicure en Puerto Vallarta. Happy Feet Pv', '+523222227633', '+523222227633', '
Ignacio L. Vallarta 229A, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6039783, -105.2360712,
  'https://lh3.googleusercontent.com/p/AF1QipP0huJitib2mW0zR-ivpF6VulD6pphNlWbgc8ib=w425-h240-k-no', 4.5, NULL, 'Spa de día',
  '{cuerpo_spa,uñas}', NULL, 'https://spahappyfeetpv.site.agendapro.com/mx', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147bec905fcd1:0xee1fe7254ada401d', 'Peluquería Barber Shop Jarretaderas', '+523221317003', '+523221317003', '
Calle Francisco Villa Ote. 45, Costa Coral, 63735 Las Jarretaderas, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6913594, -105.2728706,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqZR0UNozk_m6WaUW5AJFtpWknCyLhErkivreMZxdxuf7i2gAAoTcNfzWpCm45Mp013T_dduT7t5KsWEjmQighKFwWLsFUOqSWFV0YVwyzuIasgZgjVtji89_i9Q-qJy3KOgQ3Y=w408-h248-k-no', 4.4, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c39d1d1c7:0xc86a8acd5d798058', 'Peluquería El Caico', '+523221335766', '+523221335766', '
48380, Aquiles Serdán 334, Emiliano Zapata, Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6048504, -105.2348825,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepZ3MRUdrQoH5vFq5fSW8xZFauvmt4uK3tSlq6z_ec0xXLZauCVmzGnMl_MlcYmaeUHaf3lGizVMmYN6GAT62PzD97cBeT4lZ6343PupockIYzsbqRvPCym619LmlIDhLWHEAK8ig=w408-h544-k-no', 4.9, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f96f80b52d3:0x43e8563cd6e4d262', 'Peluquería El Pitillal', '+523221575016', '+523221575016', '
Benito Juárez 160, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6514236, -105.2181406,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer8aeWzX6tnS36-a-aIwPwTs4V7NhvXunp5Q6mNSpuLXjDtT67-_N0OVxBx_lexiGtGs4NSfYNO6SNHpu0jz0T_YO30JrbCzxRMEf_kJ53S9_Hn41EObGv2IT9XZoG1uvQ9RMkh=w408-h544-k-no', 4.5, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145972176dadb:0xb7129161e74fc9ac', 'Peluquería El Vecino', '+523221039800', '+523221039800', '
C. Politécnico Nacional 174, Educación, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6606748, -105.2381534,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwephhhe-9Gz1nRA5jkfgwMEUVM0s3jU0d-bAEeBWmkMmbY-MZl0LZQeeR9uj09S51Ah7_7ejMjuBE9hILX9ro2SVkchF8EfXZIGzhzZpIEzGVeR5AuBIgqEXikXfO7gQVcCei9bhGaP_7Qw=w408-h544-k-no', 4.6, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454e963939cf:0x47c99fd2e7dc22fb', 'Peluquería Masculina Paris Londres', '+523222222929', '+523222222929', '
Libertad 268 Centro, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6069512, -105.2355324,
  'https://lh3.googleusercontent.com/p/AF1QipNlxlUQ2qZ-dTlw_mD8nMeR8oG8p3JvuLd4DFat=w408-h306-k-no', 5.0, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454dab6034f3:0x98612be2aa6a6795', 'Peluquería Unisex El Galletas', '+523221019752', '+523221019752', '
C. Juárez 933, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6125526, -105.2323614,
  '//lh6.googleusercontent.com/563Rv1nnLqiO_EMz8Ae9Dlb3r5ZJeYPVypLj1mtADGiQLH19J3HPKwaYhrLjjw=w427-h240-k-no', 4.4, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214564794bf69f:0x4955ccf237732284', 'Peluquería Unisex Tolentino''s', '+523227790572', '+523227790572', '
Av. Francisco Villa 680, La Vena, 48320 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6327485, -105.2256319,
  '//lh4.googleusercontent.com/9UVRUFMrcLLi_dTlADFQ-vviEhulb9lH78OvURgHfyt5ItSMss-7A79rur_P-pPI=w427-h240-k-no', 4.7, NULL, 'Peluquería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421456e145c7f1d:0x61e495f0d002730f', 'Peluquería y Estética " La cuata Iveth"', '+523221565512', '+523221565512', '
Av. México 215, Las Mojoneras, 48317 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6867416, -105.2261976,
  'https://lh3.googleusercontent.com/p/AF1QipMKAIt1lvQjBx9kSQ4Wzc4Sk5VC0iuMQuvJKBMo=w408-h306-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145fc2c3d604d:0x9d89ad13f4243549', 'Pennlash', '+523221726932', '+523221726932', '
Morelos 509, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6103216, -105.234715,
  'https://lh3.googleusercontent.com/p/AF1QipMbvGpDN4MHz3Oi40hqIDDdy5EFTTF7h3UEHzXf=w408-h408-k-no', 5.0, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.instagram.com/pennlash.pv?igsh=aHB5dXdlNHNvMnM1', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f76b9e33d17:0xe0e1b003f980003f', 'Perfect Beauty Studio', '+523223190688', '+523223190688', '
Ceiba 101, Los Delfines, 48325 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6337418, -105.2146983,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=frieJLEQd-lHy65poNZDdA&cb_client=search.gws-prod.gps&w=408&h=240&yaw=322.37863&pitch=0&thumbfov=100', 5.0, NULL, 'Proveedor de productos de belleza',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145adc1e147fd:0x175fca60a9a47ca3', 'Quinde spa', '+523222138331', '+523222138331', '
Mezquital 589-B, Los Portales, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6626393, -105.2277405,
  'https://lh3.googleusercontent.com/p/AF1QipOwAgPFE0Q85fHQTMoD_OREMG6MUzyYYpmLip2P=w427-h240-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145a5694246ff:0x5c724d5cfb38694c', 'Relaxing spa', '+523223060403', '+523223060403', '
Venustiano Carranza 235, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6029568, -105.2362813,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqvzocvJO55gGjpeQbZlxYMyeUeVpvQaqK_8Hdc5v-Jj4NV8M8ffyFuIzvHycZdIhRuPjM3Amm7lBMB8St95Ig8_PmXSCThg7UgKyMzi8KFkwq8w7Z6Tn-73DrcpyzjPJSkpltU=w408-h725-k-no', 4.6, NULL, NULL,
  '{cuerpo_spa}', NULL, 'https://relaxingspapv.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214fdc74527739:0xce3572a5b2851799', 'STAR LASH | Extensiones de Pestañas | En Puerto Vallarta', '+523221247742', '+523221247742', '
Calle 16 de septiembre 1378 Local B Colonia El Mangal, Supermanzana Delegación, el, Coapinole, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6528102, -105.2009881,
  'https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=JGzvotBVLIrbC-k5ryQTIg&cb_client=search.gws-prod.gps&w=408&h=240&yaw=90.78264&pitch=0&thumbfov=100', 5.0, NULL, 'Eyelash salon',
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455246f10c8f:0x1715e82fe7572197', 'STUDIO ULI / Hair and Make-up Artist', '+523222377771', '+523222377771', '
Insurgentes 108, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6053978, -105.2344079,
  'https://lh3.googleusercontent.com/p/AF1QipP4g_hnvLoQnbnsT5-Z_1YjaPUHieqiE7SWkwsm=w408-h720-k-no', 4.9, NULL, 'Peluquería',
  '{cabello}', NULL, 'https://www.ulistudiomx.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421459f701be5a9:0xb3891fa6234ce5d3', 'Salon Spa Sol y Luna', '+523222212663', '+523222212663', '
Esq. Ingreso, Av. de las Garzas 240, Zona Hotelera, Zona Hotelera Nte., 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6498272, -105.2421705,
  'https://lh3.googleusercontent.com/p/AF1QipPNnlbkiDUecS3wcdCt7nH1-GCPU9xo4ya4vQJU=w408-h306-k-no', 4.8, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'https://www.spasolyluna.com/servicios/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455b2b20a5df:0xa51e884f77c833ac', 'Salón Amin Lenz STUDIO Asesor De Imagen Estilista ,Colorista ,.Extensionista Dominando Más De 20 Tecnicas', '+523221348188', '+523221348188', '
C. Perú 1034, entre Argentina y venezuela, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6153092, -105.2311545,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwep12kYYZ_NnrfA20GvvuLQKSDPsQLr6DYuXGXzSo-T_zW_W_b-AdoktnuisJRwysCf_WHc7DB5S5fq4VtE17gcAkvAPpy0rIskDFc2geT-OM57XS0CkLCHyZAlx9laxGZmwU_XuXRq32L_T=w408-h544-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://allmylinks.com/lenz-amin', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f80f3619abb:0x81d1286f23b2dbfb', 'Salón Lizz Castello', '+523222249797', '+523222249797', '
Av Hacienda El Pitillal 218-Local D, Ex Hacienda El Pitillal, 48318 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6463727, -105.2136126,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerVZBDroF9JV0jueYDL4tPflh_BJ5VdRBIdud-DssrdGva0CfaLrF0OfxCdBbBRIFuttpnWnyIk6s0Z-etUmj5THtnPN8occifVY2cLOd9PuYt59jDKKzofLPm7DRLISYVOMsOf=w408-h306-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/EsteticaLizz/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454f11cc3f91:0x100ff2d30faef936', 'Salón Malecón', '+523222204988', '+523222204988', '
Av. Francisco Medina Ascencio 1863, Zona Hotelera, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6315774, -105.2294001,
  'https://lh3.googleusercontent.com/p/AF1QipPM3Z0Tr8Ryu02Q7wFaUwPyqNLVjt_-1DXl66-v=w408-h408-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/Salonmalecon', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214ffac9842a41:0x1d126a279eb690b', 'Salón de Belleza ~ PEACH ~', '+523222112157', '+523222112157', '
C. Revolucion 54, Bobadilla, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6562796, -105.2230025,
  'https://lh3.googleusercontent.com/p/AF1QipMFBjbhnRpoJop8eaf6xUqEaZkAzXEhCK7dBmF9=w426-h240-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/profile.php?id=100007793477941', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421495851ae9fd5:0xed8df1ee9acdd294', 'Salónica Beauty Salón', '+523221356129', '+523221356129', '
Calle Gaviota 329, Los Tamarindos, 48280 Ixtapa, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7126775, -105.2147247,
  'https://lh3.googleusercontent.com/p/AF1QipOe1sSRKefqLhC9e7SyafnpkuFfNzgzoqXvmoxo=w408-h534-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/profile.php?id=100055372523052&mibextid=ZbWKwL', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452cf8237d69:0x81fbe5e5751a6119', 'Samer Spa', '+523222062199', '+523222062199', '
Lago Victoria 158-LOCAL 3, Fluvial Vallarta, 48313 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6425942, -105.2216598,
  'https://lh3.googleusercontent.com/p/AF1QipPkcv-gWts7lGnYtIFwsxm4OjK8qSmM5pOTqc6u=w408-h544-k-no', 5.0, NULL, 'Spa y gimnasio',
  '{cuerpo_spa}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214559ed5ee455:0xe505b9d469e7297c', 'Sea Nails Boutique & Spa - Uñas, Mani, Pedi, Alaciados, Laminados y Cortes de Cabello en Puerto Vallarta', '+523222641269', '+523222641269', '
Av. de los Grandes Lagos 291-Loc. 12, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6532338, -105.2258911,
  'https://lh3.googleusercontent.com/p/AF1QipOdd1gPScxkKo4AeQAPnRJ0Xbnw7mrVViFnAkJJ=w408-h326-k-no', 4.1, NULL, 'Centro de estética',
  '{cabello,cuerpo_spa,uñas}', NULL, 'https://seanailsboutique.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421455c9a1162cb:0xff8fb4069cce06db', 'Shalom - Body & Mind In Harmony', '+523227283131', '+523227283131', '
San Salvador 319, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6204347, -105.2288905,
  'https://lh3.googleusercontent.com/p/AF1QipNfjUSYI2YdNMN5lzdxhadoop1_bCyJIlaFpeU0=w408-h743-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214599330cb9fb:0xefabdf1a8d87a400', 'Shine Nails and Beauty Center', '+523221058171', '+523221058171', '
48312, Fluvial Vallarta, 48312 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.641747, -105.2224771,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer5cVueBPSC-oCHB3acX0qd1ldrUM1RTvR3c7lYeSB0SAXCR954AvHshgWrBlqHWk_5kjZ9XBptMus5MrVokDkv-t4N4Gi2_4nMzUckEh80iob6tzaclELPN_GmrVgh-ve_V6wjvg=w408-h306-k-no', 4.5, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457a85ad8001:0xb1eafa5dfdde75f0', 'Sirenas Beauty Hair & Yarit Reynoso Jewelry', '+523223017238', '+523223017238', '
Viena 116, Díaz Ordaz, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6378835, -105.2306398,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepA-vdD2rC7b7BT1IzBYWmTgepxBddxYYWCS8qPccqOAZYU6Sy66XFUPWsqcDxxObUy49B1ILcgc2CTEPPAAu9oCFLxmIsTIKDI8FYZDGYtZEbbHs5tg9w-3ZVHsYFDyLZqEf2sty1oqIM=w408-h306-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454b5e0c2a09:0x35807ca517a84c31', 'Spa by Playa Los Arcos', '+523222267128', '+523222267128', '
Olas Altas 380, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6016353, -105.2378805,
  'https://lh3.googleusercontent.com/p/AF1QipNhGhBwi42BIY7DccnFdD1kXdUx77TumlhzBwFT=w408-h272-k-no', 4.4, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'http://www.spaplayalosarcos.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145006cff4f85:0x3ce2522733ef7889', 'Spa luna llena Massages', '+523223018395', '+523223018395', '
C. Juárez 479, Proyecto escola, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6096672, -105.234447,
  'https://lh3.googleusercontent.com/p/AF1QipM2kEzazn1yii9eGuh_wHriS-5K3dw2RFseBbhG=w426-h240-k-no', 4.9, NULL, NULL,
  '{cuerpo_spa}', NULL, 'https://www.facebook.com/people/Spa-luna-llena/61573772725648/#', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457b3b33d32b:0xc4401bbf4d0b626c', 'Spiral Hair Studio by Leslie Panini ( Spiral Salón)', '+523222132124', '+523222132124', '
Hamburgo 148 C Colonia, entre Palm Springs y Hamburgo, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6376729, -105.2256474,
  'https://lh3.googleusercontent.com/p/AF1QipMBZECSqAPo1Zwx9fjzuYB77M_nnOAhdhVvvHXx=w408-h544-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454f4dfc7fb1:0x9e8a1ed751e9cc8d', 'Steff Ramírez Wedding Makeup', '+523223199880', '+523223199880', '
El Faro 532, Villas del Puerto, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6599839, -105.2322734,
  'https://lh3.googleusercontent.com/p/AF1QipPhHS7K7v7-nPJaNfRaAi2QXjwgbhbtK47EUKl1=w408-h271-k-no', 5.0, NULL, NULL,
  '{maquillaje}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421469377204b55:0x6ed4524b57c51cd3', 'Studio 90•86', '+523226882713', '+523226882713', '
Plaza GSM Local, Blvd. Nuevo Vallarta 65-No. 2, 63735 Nuevo Vallarta, Nay.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.7094597, -105.2829472,
  'https://lh3.googleusercontent.com/p/AF1QipPB6BCYep-7qVwfZdfaVLhx8Yey-DX-IXi5IU2c=w426-h240-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145004deff76d:0x568e2699f5edeafb', 'Studio Figurati', '+523223535808', '+523223535808', '
C. Portal Constitución 576 c, Los Portales, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6625036, -105.2278776,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqTZi5doiSNmvLvcd3xEyO0RQCqb5WVOHOyvIK9_Ce_p9vXFLrRtaZip8G46u2H_eHFhKffWDmi4QbE-UxYUO_QdsJfI29bFS5hYtuyWaFsgzQh2HDnDzuO70X-7hP0OYpqyWOrDsjtGLNf=w408-h544-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.instagram.com/studiofigurati_?igsh=MWQ4djN4cjE3Y2kxYg%3D%3D&utm_source=qr', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145b7c48d6b63:0x62d33f104c9f5094', 'Studio Johana Marroquín by Arte en Uñas', '+523221673645', '+523221673645', '
Condor 129, Fovissste 96, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6425928, -105.2128585,
  'https://lh3.googleusercontent.com/p/AF1QipMAu3_ahatS95EgvTuuu9-GIhWP_aYYVHSKHGBE=w408-h410-k-no', 5.0, NULL, 'Centro de estética',
  '{uñas}', NULL, 'https://www.facebook.com/share/164QL2k5iJ/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f2d7f73bf61:0xb528dad2707310d', 'Studio K Nail Bar & Lashes', '+523222099893', '+523222099893', '
Fco, Av. Francisco Medina Ascencio 1700, Olímpica, 48330 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6271211, -105.2295357,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepN8MZSyxV5n3cfCoCTpn1wBd6z8rxBqCUMqZZTS-ltt9GwL4JLX6zxHsw9fHrAAxv_zphqzJpeGFQECMTmxvJDv6NKZebG8cYO0YkR5FG3vtE79l8KHg2jNt5zOCjmO2IDPjpb9QQF3For=w408-h306-k-no', 4.6, NULL, 'Salón de manicura y pedicura',
  '{pestañas_cejas,uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145633319c225:0x6afaad29e2aeb4d0', 'Studio R - hair salon', '+523222319330', '+523222319330', '
C. Prisciliano Sánchez 605-local 2, Plaza, Albatros, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6563846, -105.2250401,
  'https://lh3.googleusercontent.com/p/AF1QipNgfeLWdTn7adJVujNyf-Nffn1vVvtoCTjxT2Tf=w408-h272-k-no', 4.8, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://studior.site.agendapro.com/mx', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421473155e8010d:0xbca42f5ed3cb5ec4', 'Studio de pestañas Lu', '+523223533545', '+523223533545', '
C. José María Morelos 43, 48291 México, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6947564, -105.2438296,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqny68KdZaYz7Jt3wBaaSpgvAoNEska4cWDNH10ikmLBPTl9QqdpeZx6-EwSpGaafsKSGC0dbQJzVfnH3i1man66Av8q5cTen3S4on43mYLFrK8A6ioA3RFGzLvDm3ASQvhpovQ=w408-h310-k-no', 5.0, NULL, 'Centro de estética',
  '{pestañas_cejas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214570b6dac64f:0xc12d7dc169ade56', 'Style Beauty Salón', '+523222245737', '+523222245737', '
Plaza Caracol, Av Los Tules 152-Int. F31, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6406649, -105.232332,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwerPbWve12zen9MVj4Vf_6I7-bIOBgSLCNLUZqNFGVeCK71qSvOWEijwXdG-7lJb_KGXw1QxxR0CoHWdBsmC_ks95bAoOdjRyejviyo1gDkJzFnf3REgaqe6rlrBOP1rLqkN4w4=w408-h544-k-no', 4.7, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842147e8e2c2e71b:0x15e235b4f911fb5f', 'TEBORI BEAUTY FOR EVERYONE', '+523221276291', '+523221276291', '
Valle del Mar 111, Las Mojoneras, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6927486, -105.2243683,
  'https://lh3.googleusercontent.com/p/AF1QipMlm2yzI6YjLbt2nfuisGa65gzpBUeywmRp6MQq=w408-h306-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/microbladingteboriartist', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214ff43facf64f:0xc235ad836a93d09d', 'Terry Barbershop', '+523223516951', '+523223516951', '
Las Torres 246, El Toro, 48296 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6507815, -105.2127164,
  'https://lh3.googleusercontent.com/p/AF1QipOw0R-CbfrP7DZbVvyEx0mYHclMrXsGIDjEmxXa=w426-h240-k-no', 5.0, NULL, 'Barbería',
  '{cabello}', NULL, 'https://instagram.com/terrybarbershop.1?igshid=NzZlODBkYWE4Ng==&utm_source=qr', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421458d3dfd581f:0x5b7ba8d73a86decd', 'The Barber Club', '+523221059366', '+523221059366', '
C. Prisciliano Sánchez 519, Las Moras, Villa del Sol, 48315, 48313 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6558173, -105.2318226,
  'https://lh3.googleusercontent.com/p/AF1QipMZfC3Nm_DZkddHIad7eGxi8q5t1mUJgcq2t65m=w408-h306-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, 'https://instagram.com/barberclubpv?igshid=YzcxN2Q2NzY0OA==', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f60c5e0778b:0x1d6be74780e631c7', 'The Barber Shop Roman', '+523333390554', '+523333390554', '
C. Exiquio Corona 491, Bobadilla, 48298 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6597157, -105.2186929,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepgi1CxXvTXtLL9Qcnx9na8y1adFdV0mf6Bu0E5dRm0fxfyr_PujaHfdLwv330vlWk6n9tncMhlnYa0JbTxEG--qw3Wi9GsPF7qnFXc5Rd7GVm56NaKYJgxsgYShu92PLvoCWF3=w408-h408-k-no', 4.7, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145afdabe4f0d:0x167f86058ff3f5ae', 'The Golden Barber Shop', '+523221540723', '+523221540723', '
Blvd. Francisco Medina Ascencio 2735, Zona Hotelera, Marina Vallarta, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6509083, -105.2419088,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweoigyzDf55F0gq-7nQEx-TMAZIxsYkw4oWxza7WwUWZTULP-x_81mV51pHeClyWrLYNqpV1q0dLxh971vH3rfZ5AN4qX8oJJwtRjNFB-KqQOIDGNeBxnxcpXc0D-BSFFixBfA-VouakAj0=w408-h306-k-no', 4.9, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454391be8f41:0x46545734b1b9d0e5', 'The Hit Room Barbería', '+523223693266', '+523223693266', '
Avenida Mexico 1464, Plaza 20 6-Local 18A, Villas Universidad, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6772893, -105.2255179,
  'https://lh3.googleusercontent.com/p/AF1QipM3eyK3m3HCt0P33_NPm_RYyqyuWG8ty0UQNVMF=w408-h714-k-no', 5.0, NULL, 'Barbería',
  '{cabello}', NULL, 'https://www.facebook.com/share/1FroK1Qytt/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145d528a5cca5:0x67109197802c2f7c', 'The Nail Spa', '+523222403060', '+523222403060', '
Libertad 160, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6064775, -105.2337966,
  'https://lh3.googleusercontent.com/p/AF1QipPbKVxwrEHHirO2sLhgOUlxs1R34LlNyzXBKJZ4=w408-h544-k-no', 4.7, NULL, 'Salón de manicura y pedicura',
  '{cuerpo_spa,uñas}', NULL, 'http://thenailspa.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214511d21539e3:0xb08d93ce572972d1', 'The Venue PVR Barber, Nails & Spa', '+523222094748', '+523222094748', '
C. Juárez 541, Proyecto escola, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6102426, -105.2340347,
  'https://lh3.googleusercontent.com/p/AF1QipMbSY4d2KeXdWtt_8RDRQKG9NiSU44cN88pKpMt=w513-h240-k-no', 4.8, NULL, 'Barbería',
  '{cabello,cuerpo_spa,uñas}', NULL, 'https://www.fresha.com/book-now/the-venue-pvr-g2ej4dzk/services?lid=788607&pId=740995', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145434c0ba2cf:0x522abc1c60c54e5e', 'The Witchery Salon', '+523221347485', '+523221347485', '
C. Honduras 139C, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6190791, -105.2313668,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepNGjk_YzlwFt62LRug-vJP7s01Yag0SJ36BuCYDrEGxEumAjYkabwWN5ZrcNk0KM0fuydgRyfST46iFHx9xg8aEdsfs1-8_zsT7wthrafz_A9fWLozq0bJ94LEPFtvr_ld9uk=w408-h306-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.thewitcherysalon.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421453cba0ed3f5:0x10015f7cc21ca75d', 'The nail bar pv', '+523223777418', '+523223777418', '
C. Perú 1201-B, 5 de Diciembre, 48350 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6182407, -105.2307899,
  'https://lh3.googleusercontent.com/p/AF1QipOlfu7j9IiRyr4Ymn1pE3uGr7_RMjBKR8rDQv1i=w408-h725-k-no', 4.8, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454cf65eb88d:0xa1beed4f3935936e', 'Thomas Simon Salon', '+523226882019', '+523226882019', '
Venustiano Carranza 290, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6029841, -105.2352448,
  'https://lh3.googleusercontent.com/p/AF1QipN4CPxqgDW3rYBbPG9kT0IVB-Fdrw42BC-hfQEl=w408-h244-k-no', 5.0, NULL, 'Centro de estética',
  '{cabello}', NULL, 'https://www.facebook.com/thomassimonsalon?mibextid=LQQJ4d', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421451e8a1f5371:0x3064aa6d96d964f3', 'Top Lashes & Beauty Studio Pestañas Vallarta, Lash Lifting, Microblading', '+523221162643', '+523221162643', '
Av Los Tules 178-Local F 24, Díaz Ordaz, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6402799, -105.2325923,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwep0dHEiYXFmm7eOuG3DTguYjzmKVoFLnE3RAl-wjTFWCRc0OuKrj7H0zl9VrEdfQsx8OamDo0qu-sU54kVKJKHEu24F91kZrJRietQYKoaQK5qVKoszqWiB6Dcri3Fx3WP4Loc=w408-h529-k-no', 4.6, NULL, NULL,
  '{pestañas_cejas}', NULL, 'https://www.facebook.com/TopLashesStudioPV/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84215ab4b597063d:0xaa686d4a474179bf', 'Toya''s Salon', '+523222230696', '+523222230696', '
Amapas 129, Zona Romántica, Emiliano Zapata, 48399 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.599783, -105.2383808,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweqlsWGND8xMnVSbwc6DK2r2J8--CgGAxV0nBeIQ2c6ygStEJHaVohHhMhcljq2n6Yj0vP7Nga2yT1RzSePPQhXq2sUtx-uLBJD9Jpa1mJE0Hd_0HnhMD0-FGZ-_jfb49FyuMZ7Rbg=w408-h306-k-no', 4.6, NULL, 'Centro de estética',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145aa18ecbb67:0xed6bd23cec4802fd', 'Tropical Beauty PV', '+523223056015', '+523223056015', '
Blvd. Francisco Medina Ascencio 1939, Zona Hotelera, Norte, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.632141, -105.2294862,
  'https://lh3.googleusercontent.com/p/AF1QipMuYe6Df913qhj2Ok6z1UojOX7LeJ7QnmoUcGCY=w408-h544-k-no', 5.0, NULL, 'Salón de manicura y pedicura',
  '{cabello}', NULL, 'https://www.instagram.com/tropicalbeautypv/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452c87f8ccad:0x88b2f8b43d0a3b7a', 'Urban Beauty - Nail Studio', '+523223691405', '+523223691405', '
Libertad 240 b, Centro, 48300 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6071823, -105.2358026,
  'https://lh3.googleusercontent.com/p/AF1QipO1Xq3tcgylAZJ8l7aFk9aJ_6rXtPCxSH8o3LIE=w427-h240-k-no', 4.8, NULL, 'Centro de estética',
  '{uñas}', NULL, 'https://www.facebook.com/profile.php?id=61555325501270&mibextid=hu50Ix', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214599c058de51:0x4383d84a05c526cb', 'Uñas Norma Galerías Vallarta', '+523222090803', '+523222090803', '
Blvd. Francisco Medina Ascencio 2920-Local 232, Educación, 48338 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6575595, -105.2391824,
  'https://lh3.googleusercontent.com/p/AF1QipOtxr7vpH0CeTkdFHXXKSagrJoUf2T3YV3ixaQN=w408-h272-k-no', 4.4, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.facebook.com/unasnormavallarta/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f8fd0e8246d:0xdef36353aa48bd5e', 'Uñas Norma Plaza Caracol', '+523222935050', '+523222935050', '
Plaza Caracol, Blvd. Francisco Medina Ascencio Km 2.2-Local I 11 y 12, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6407622, -105.232888,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweq0kVuSXwA4WAKnw0R-uoBcu4gFYRegIIBtCb4amFWBiHbnz8rfghie7dUx6uX0EZMnEnqCCIuT46E1I8p83NqqTYT2ZYvjhbjCyY28UIrcyABuENzV99A-L6MV3ptXES-OYEE9yTZHqnwz=w408-h591-k-no', 4.5, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.facebook.com/unasnormavallarta/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145c6ef5fe81d:0x1323f646cad8c97e', 'Uñas Norma Plaza Neptuno', '+523222091094', '+523222091094', '
Plaza Neptuno, Blvd. Francisco Medina Ascencio Km. 8.7, Marina Vallarta, 48335 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6678977, -105.2491023,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwepdZ3A-POoRGSu0sBRRZm7wL_9c3igAd6yVASY1VaY1AKlwphfwDDJ0iNXmvhcJrDIkUq1zxfKeOgqe5gYjEvWhPF8pr80sV5rHKCuP9bfTCXLKVix90OGTTsgGL6HgAKOmqV02=w408-h544-k-no', 4.6, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, 'https://www.facebook.com/unasnormavallarta/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145e39873972b:0x7a67d386ac10636c', 'Uñas pies y más Vallarta', '+523221903192', '+523221903192', '
Plaza Caracol, Av Los Tules 178-Local D1, Las Glorias, 48333 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6417245, -105.2325804,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwergNgmpSUAkQ4muMuLD4pQy9H3Ugo2O8Q59C3IYBD3kgsn73uHnMMZ9y-Hra9H4D8wQLXVQyj-yDKyKFbEdfySooTtMw34e3KALBDztvSeQaQC2-oqAd2KIvtJYq-Ko0_Hjy1QJpjJT5oY=w408-h544-k-no', 4.5, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454d8ee8eea5:0x53c7630cd0aa3125', 'Vallarta Barbershop / Barbería Puerto Vallarta / Barbería', '+523225961744', '+523225961744', '
Lázaro Cárdenas 236e, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6033717, -105.2363688,
  'https://lh3.googleusercontent.com/p/AF1QipPF769hPwCZb6jQPeDv6VN9W-b5ZjUJc37JuKFS=w408-h612-k-no', 4.7, NULL, 'Barbería',
  '{cabello}', NULL, 'https://www.instagram.com/vallarta_barbershop1?igsh=aTRkZXZ3bmk1bmdi', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421458155555555:0x99ab9dadba5e5520', 'Vaman Spa', '+523222064142', '+523222064142', '
Venustiano Carranza 368, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6033488, -105.2334362,
  'https://lh3.googleusercontent.com/p/AF1QipMA9-NMdFDd2CU2Kpg-ntWjTmgC7wsAPw7xYBBl=w408-h306-k-no', 4.9, NULL, 'Spa',
  '{cuerpo_spa}', NULL, 'http://vamanspa.com.mx/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f7e114067b1:0x758468b68d7fea90', 'Venus Cosméticos', '+523221315739', '+523221315739', '
20 de Noviembre 569-A, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6530384, -105.2185521,
  '//lh5.googleusercontent.com/nrQ73PEjyVbSCNt3SpJ9uAjIfN6SjFg_fZGtHCngKDYQl80_azdrEvyr_hpYn0sx=w427-h240-k-no', 4.6, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214584c154fa73:0x894599925a0392db', 'Veros Nails', '+523221141017', '+523221141017', '
Tatewari 4, Aramara, 48302 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6549096, -105.2301042,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAwer8A9YS6AucWOv4vZh5EpwVST-JK0SFits5qlznL_GNWD5noWbuDgp6Z4Dd1_Oc8nzvcPgB3u8jaWrqLYfCjJxU0XSpEcn_eryPnqO3zFiyxotGRIEwUnQpPG3gV5pMqB3zoEA-nEIjPG31=w408-h544-k-no', 4.6, NULL, 'Centro de estética',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421451b75870279:0xe1033cebe98591e', 'Vintage nails Vallarta', '+523223697944', '+523223697944', '
Av. Francisco Villa 900-3, Las Gaviotas, 48328 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6360223, -105.2232061,
  'https://lh3.googleusercontent.com/p/AF1QipPwSfB4-M7Fo4NAAmN_rtIj7a6md0QDFao-P133=w426-h240-k-no', 3.6, NULL, 'Salón de manicura y pedicura',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x842145082caa2fcf:0xfaf937839e62ab2d', 'Vita Spa Vallarta', '+523222622990', '+523222622990', '
Basilio Badillo 356, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6025969, -105.2338111,
  'https://lh3.googleusercontent.com/p/AF1QipPpjXMIvQlCYmK6QZHoug2djHlX0M6Gnos0YMq-=w408-h306-k-no', 5.0, NULL, 'Spa de día',
  '{cuerpo_spa}', NULL, 'https://vitaspavallarta.com/', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c65218873:0xfaf0f8f46fecc8ca', 'Votre Salón', '+523221130252', '+523221130252', '
Aquiles Serdán 242, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6044525, -105.2365592,
  '//lh4.googleusercontent.com/X6GeiRUXA9JhVVPOqJ2WuttiI_h0QQpktg5Ws_-suIUsX2v4jM81ILyFmK5scIiS6w=w427-h240-k-no', 4.9, NULL, 'Centro de estética',
  '{cabello}', NULL, 'http://www.facebook.com/votresalon', NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x84214f2484bb41e5:0x56cd581ecb1d5560', 'Yosi Nails', '+523221605949', '+523221605949', '
Cl. Fco. I. Madero 125, Centro Pitillal, 48290 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6513951, -105.2168928,
  'https://lh3.googleusercontent.com/p/AF1QipPAgPe3IxmUQh9U34harcjMSM_Sq98KhaTyodn5=w408-h544-k-no', 4.9, NULL, 'Centro de estética',
  '{uñas}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421457734469efb:0xd20c2ec1425d945c', 'nbc Beauty Suply', '+523221358175', '+523221358175', '
Plaza Caracol, Av. Los Tules 178, Local 5, Zona F, Versalles, 48310 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6415802, -105.232842,
  '//lh3.googleusercontent.com/-sN3vUSjQj7uPKZJjxFBTB9ByyrVnbxaafjSzuwyjJmOHZjfsen9sPwUctQIx2f-=w408-h726-k-no', 4.3, NULL, 'Tienda de cosméticos',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421454c418e2029:0xfe099e97ab4158aa', 'peluquería unisex ALEX', '+523221385030', '+523221385030', '
C. Fco. I. Madero 287, Zona Romántica, Emiliano Zapata, 48380 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6042906, -105.2354988,
  'https://lh3.googleusercontent.com/gps-cs-s/AHVAweq3LhEk_3kpqsmebHs23TzSSaNDXZICFSIvcKno8h2_beP2Ev36zWfdbbxJ7miT3IcRGh4v1EaKxEl6JjTPeIs-0MbsDX93FCMN_S-VZPNh4BROJmI5sA0I7UqdAGwhSSlDFffP0g=w408-h306-k-no', 4.8, NULL, 'Barbería',
  '{cabello}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

INSERT INTO discovered_salons (
  source, source_id, name, phone, whatsapp, address,
  city, state, country, lat, lng,
  photo_url, rating, reviews_count, business_category,
  service_categories, hours, website, facebook_url, instagram_handle,
  scraped_at
)
VALUES (
  'google_maps', '0x8421452c5254206f:0xb3f4339921a96def', '💈SUPRA BARBER SHOP💈', '+523223308580', '+523223308580', '
C. Prisciliano Sánchez 625, Albatros, 48315 Puerto Vallarta, Jal.',
  'Puerto Vallarta', 'Jalisco', 'MX', 20.6561166, -105.2245995,
  'https://lh3.googleusercontent.com/p/AF1QipPstvathdWEWE6pU1_wBaknhjfkIXDL778vQiNE=w408-h276-k-no', 4.8, NULL, 'Barbería',
  '{cabello,cuidado_especializado}', NULL, NULL, NULL, NULL,
  '2026-02-01T22:48:35.781369+00:00'
)
ON CONFLICT (source, source_id) DO UPDATE SET
  phone = COALESCE(EXCLUDED.phone, discovered_salons.phone),
  whatsapp = COALESCE(EXCLUDED.whatsapp, discovered_salons.whatsapp),
  address = COALESCE(EXCLUDED.address, discovered_salons.address),
  lat = COALESCE(EXCLUDED.lat, discovered_salons.lat),
  lng = COALESCE(EXCLUDED.lng, discovered_salons.lng),
  photo_url = COALESCE(EXCLUDED.photo_url, discovered_salons.photo_url),
  rating = COALESCE(EXCLUDED.rating, discovered_salons.rating),
  reviews_count = COALESCE(EXCLUDED.reviews_count, discovered_salons.reviews_count),
  business_category = COALESCE(EXCLUDED.business_category, discovered_salons.business_category),
  service_categories = COALESCE(EXCLUDED.service_categories, discovered_salons.service_categories),
  hours = COALESCE(EXCLUDED.hours, discovered_salons.hours),
  website = COALESCE(EXCLUDED.website, discovered_salons.website),
  facebook_url = COALESCE(EXCLUDED.facebook_url, discovered_salons.facebook_url),
  instagram_handle = COALESCE(EXCLUDED.instagram_handle, discovered_salons.instagram_handle),
  scraped_at = GREATEST(EXCLUDED.scraped_at, discovered_salons.scraped_at),
  updated_at = now();

COMMIT;
