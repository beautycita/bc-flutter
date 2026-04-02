-- Fix staff.position for existing owners who registered before the edge function fix
UPDATE staff SET position = 'owner'
WHERE position IS NULL
AND user_id IN (SELECT owner_id FROM businesses);

-- Ensure position column has a default for future inserts
ALTER TABLE staff ALTER COLUMN position SET DEFAULT 'stylist';
