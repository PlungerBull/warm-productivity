-- Migration: Seed global_currencies with common currencies
-- Adds decimal_places column and inserts ~30 widely used currencies.

-- Add decimal_places column (most currencies use 2; JPY, KRW etc. use 0)
ALTER TABLE global_currencies
  ADD COLUMN IF NOT EXISTS decimal_places INTEGER NOT NULL DEFAULT 2;

INSERT INTO global_currencies (code, name, symbol, flag, decimal_places) VALUES
  ('USD', 'US Dollar',              '$',    '🇺🇸', 2),
  ('EUR', 'Euro',                   '€',    '🇪🇺', 2),
  ('GBP', 'British Pound',          '£',    '🇬🇧', 2),
  ('JPY', 'Japanese Yen',           '¥',    '🇯🇵', 0),
  ('CAD', 'Canadian Dollar',        'CA$',  '🇨🇦', 2),
  ('AUD', 'Australian Dollar',      'A$',   '🇦🇺', 2),
  ('CHF', 'Swiss Franc',            'CHF',  '🇨🇭', 2),
  ('CNY', 'Chinese Yuan',           '¥',    '🇨🇳', 2),
  ('INR', 'Indian Rupee',           '₹',    '🇮🇳', 2),
  ('MXN', 'Mexican Peso',           'MX$',  '🇲🇽', 2),
  ('BRL', 'Brazilian Real',         'R$',   '🇧🇷', 2),
  ('KRW', 'South Korean Won',       '₩',    '🇰🇷', 0),
  ('SGD', 'Singapore Dollar',       'S$',   '🇸🇬', 2),
  ('HKD', 'Hong Kong Dollar',       'HK$',  '🇭🇰', 2),
  ('NOK', 'Norwegian Krone',        'kr',   '🇳🇴', 2),
  ('SEK', 'Swedish Krona',          'kr',   '🇸🇪', 2),
  ('DKK', 'Danish Krone',           'kr',   '🇩🇰', 2),
  ('NZD', 'New Zealand Dollar',     'NZ$',  '🇳🇿', 2),
  ('ZAR', 'South African Rand',     'R',    '🇿🇦', 2),
  ('PEN', 'Peruvian Sol',           'S/',   '🇵🇪', 2),
  ('COP', 'Colombian Peso',         'COL$', '🇨🇴', 2),
  ('ARS', 'Argentine Peso',         'ARS$', '🇦🇷', 2),
  ('CLP', 'Chilean Peso',           'CLP$', '🇨🇱', 0),
  ('PHP', 'Philippine Peso',        '₱',    '🇵🇭', 2),
  ('THB', 'Thai Baht',              '฿',    '🇹🇭', 2),
  ('TWD', 'New Taiwan Dollar',      'NT$',  '🇹🇼', 2),
  ('PLN', 'Polish Zloty',           'zł',   '🇵🇱', 2),
  ('TRY', 'Turkish Lira',           '₺',    '🇹🇷', 2),
  ('ILS', 'Israeli Shekel',         '₪',    '🇮🇱', 2),
  ('NGN', 'Nigerian Naira',         '₦',    '🇳🇬', 2)
ON CONFLICT (code) DO NOTHING;
