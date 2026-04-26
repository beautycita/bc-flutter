-- Down: revert to 000002's behavior (trust gate fires on any booking_source).
-- The 000002 migration body is restored verbatim by re-running it manually.
SELECT 'noop: re-apply 20260426000002 to revert to all-source trust gate'::text;
