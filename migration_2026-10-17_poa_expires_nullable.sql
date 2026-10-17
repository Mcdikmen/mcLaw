-- mcLaw - Migration: allow permanent (sureli) power of attorney
-- mclaw_attorneys.expires_at was NOT NULL, which made an unlimited grant
-- impossible. Run this once on an already-installed database.
-- Safe to run multiple times.

ALTER TABLE `mclaw_attorneys`
    MODIFY COLUMN `expires_at` DATETIME NULL DEFAULT NULL COMMENT 'NULL = süresiz (unlimited)';
