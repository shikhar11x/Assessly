-- 002_add_admin_role.sql
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'admin';
