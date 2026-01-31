USE scadalts;

-- 1. Naprawa hasła dla ID 1 (admin). Hash SHA-1 dla słowa "admin"
-- Jeśli v2.7.4 używa SHA-1 (standard), to zadziała.
UPDATE users SET password='d033e22ae348aeb5660fc2140aec35850c4da997' WHERE id=1;

-- 2. Upewnienie się, że admin nie jest zablokowany i ma email (wymagane w niektórych wersjach)
UPDATE users SET disabled=0, email='admin@honeypot.local' WHERE id=1;

-- 3. (Opcjonalnie) Nadanie pełnych uprawnień dla użytkownika bazy
GRANT ALL PRIVILEGES ON scadalts.* TO 'scadalts'@'%';
FLUSH PRIVILEGES;
