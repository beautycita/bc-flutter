-- Add feature toggles for new marketplace features (POS, feed, portfolio).
INSERT INTO public.app_config (key, value, data_type, group_name, description_es) VALUES
  ('enable_pos',       'true', 'bool', 'marketplace', 'Punto de venta — catalogo de productos y ventas'),
  ('enable_feed',      'true', 'bool', 'marketplace', 'Feed de inspiracion — explorar fotos y showcases'),
  ('enable_portfolio', 'true', 'bool', 'marketplace', 'Portafolio publico de estilistas y salones')
ON CONFLICT (key) DO NOTHING;
