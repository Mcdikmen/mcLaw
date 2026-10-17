-- mcLaw - Migration: add defendant_citizenid to mclaw_petitions
-- Run this once on an already-installed database (install.sql's CREATE TABLE
-- IF NOT EXISTS won't retroactively add the column to an existing table).
-- Safe to run multiple times.

ALTER TABLE `mclaw_petitions`
    ADD COLUMN IF NOT EXISTS `defendant_citizenid` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'Şikayet edilen / davalı taraf' AFTER `plaintiff_citizenid`;
