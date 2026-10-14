-- ─────────────────────────────────────────────────────────────────────────────
-- County RP additions to the schema, applied automatically on resource start so a
-- missing table/column can never break the referral flow again. Every statement is
-- idempotent (IF NOT EXISTS) and mirrors the matching block at the end of install.sql.
-- ─────────────────────────────────────────────────────────────────────────────

local statements = {
    [[CREATE TABLE IF NOT EXISTS `mclaw_sentences` (
        `id`                    INT AUTO_INCREMENT PRIMARY KEY,
        `file_id`               INT NULL,
        `citizenid`             VARCHAR(64) NOT NULL,
        `jail_minutes`          INT NOT NULL DEFAULT 0,
        `fine`                  INT NOT NULL DEFAULT 0,
        `origin`                ENUM('verdict','accepted') NOT NULL DEFAULT 'verdict',
        `reason`                VARCHAR(255) NULL,
        `status`                ENUM('pending','served','cancelled') NOT NULL DEFAULT 'pending',
        `served_by_citizenid`   VARCHAR(64) NULL,
        `created_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `served_at`             TIMESTAMP NULL,
        INDEX `idx_sentence_cid_status` (`citizenid`, `status`)
    )]],

    [[CREATE TABLE IF NOT EXISTS `mclaw_bracelets` (
        `id`                    INT AUTO_INCREMENT PRIMARY KEY,
        `citizenid`             VARCHAR(64) NOT NULL,
        `file_id`               INT NULL,
        `file_number`           VARCHAR(32) NULL,
        `attached_by_citizenid` VARCHAR(64) NULL,
        `attached_by_name`      VARCHAR(128) NULL,
        `battery_minutes`       INT NOT NULL DEFAULT 4320,
        `battery_changed_by`    VARCHAR(128) NULL,
        `battery_changed_at`    TIMESTAMP NULL,
        `status`                ENUM('active','removal_due','removed') NOT NULL DEFAULT 'active',
        `removal_reason`        VARCHAR(255) NULL,
        `last_x`                FLOAT NULL,
        `last_y`                FLOAT NULL,
        `last_z`                FLOAT NULL,
        `last_seen`             TIMESTAMP NULL,
        `attached_at`           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `removed_at`            TIMESTAMP NULL,
        `removed_by`            VARCHAR(128) NULL,
        INDEX `idx_bracelet_cid_status` (`citizenid`, `status`)
    )]],

    'ALTER TABLE `mclaw_jail_decisions` ADD COLUMN IF NOT EXISTS `referral_report_id` INT NULL',
}

MySQL.ready(function()
    for _, sql in ipairs(statements) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then
            print('^1[mcLaw] schema update failed: ' .. tostring(err) .. '^7')
        end
    end
    print('^2[mcLaw] schema up to date^7')
end)
