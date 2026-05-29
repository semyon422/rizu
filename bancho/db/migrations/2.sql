-- Migration v2: remove pw_md5 column.
-- Passwords are verified via bcrypt.verify(client_md5, pw_bcrypt) only.
-- pw_md5 was stored but never used for authentication.
ALTER TABLE `users` DROP COLUMN IF EXISTS `pw_md5`;
