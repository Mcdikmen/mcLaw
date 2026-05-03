-- mcLaw - Database Installation Script
-- Run this once on your database before starting the resource.

CREATE TABLE IF NOT EXISTS `mclaw_charges_config` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `code`          VARCHAR(64) NOT NULL UNIQUE,
    `label`         VARCHAR(128) NOT NULL,
    `category`      VARCHAR(64) NOT NULL,
    `jail_time`     INT NOT NULL DEFAULT 0,
    `fine_amount`   INT NOT NULL DEFAULT 0,
    `severity`      TINYINT NOT NULL DEFAULT 1,
    `is_active`     TINYINT NOT NULL DEFAULT 1,
    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `mclaw_files` (
    `id`                    INT AUTO_INCREMENT PRIMARY KEY,
    `file_number`           VARCHAR(32) NOT NULL UNIQUE,
    `suspect_citizenid`     VARCHAR(64) NOT NULL,
    `prosecutor_citizenid`  VARCHAR(64),
    `judge_citizenid`       VARCHAR(64),
    `opened_by_citizenid`   VARCHAR(64),
    `opened_by_job`         VARCHAR(50),
    `referral_report_id`    INT,
    `jail_decision_id`      INT,
    `type`                  ENUM('investigation','case','written_trial') DEFAULT 'investigation',
    `status`                ENUM(
                                'opened',
                                'awaiting_prosecutor',
                                'prosecutor_review',
                                'indictment_ready',
                                'hearing_scheduled',
                                'written_trial_active',
                                'verdict_issued',
                                'enforcement_active',
                                'closed',
                                'archived',
                                'pending_approval'
                            ) DEFAULT 'opened',
    `notes`                 TEXT,
    `created_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `closed_at`             TIMESTAMP NULL DEFAULT NULL,
    `deleted_at`            TIMESTAMP NULL DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS `mclaw_referral_reports` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `suspect_citizenid` VARCHAR(64) NOT NULL,
    `officer_citizenid` VARCHAR(64) NOT NULL,
    `narrative`         TEXT NOT NULL,
    `charges`           JSON NOT NULL,
    `evidence_ids`      JSON,
    `mdt_incident_id`   INT,
    `status`            ENUM('pending','processed','rejected') DEFAULT 'pending',
    `file_id`           INT,
    `created_at`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `processed_at`      TIMESTAMP NULL DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS `mclaw_file_charges` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`       INT NOT NULL,
    `charge_code`   VARCHAR(64) NOT NULL,
    `jail_override` INT,
    `fine_override` INT,
    `note`          TEXT,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_evidence` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`       INT,
    `report_id`     INT,
    `added_by`      VARCHAR(64) NOT NULL,
    `type`          ENUM('text','screenshot','coordinate','item','stash') NOT NULL,
    `content`       TEXT NOT NULL,
    `label`         VARCHAR(128),
    `is_classified` TINYINT DEFAULT 0,
    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `mclaw_evidence_stash` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `stash_id`      VARCHAR(128) NOT NULL UNIQUE,
    `file_id`       INT NOT NULL,
    `created_by`    VARCHAR(64) NOT NULL,
    `sealed`        TINYINT DEFAULT 0,
    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_warrants` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`           INT NOT NULL,
    `suspect_citizenid` VARCHAR(64) NOT NULL,
    `issued_by`         VARCHAR(64) NOT NULL,
    `reason`            TEXT NOT NULL,
    `type`              ENUM('arrest','search','seizure') DEFAULT 'arrest',
    `expires_at`        TIMESTAMP NULL DEFAULT NULL,
    `is_active`         TINYINT DEFAULT 1,
    `executed_at`       TIMESTAMP NULL DEFAULT NULL,
    `executed_by`       VARCHAR(64),
    `mdt_warrant_id`    INT,
    `created_at`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_warrant_logs` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `warrant_id`    INT NOT NULL,
    `citizenid`     VARCHAR(64) NOT NULL,
    `seen_at`       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `trigger`       ENUM('login','active_notification','manual') DEFAULT 'login',
    FOREIGN KEY (`warrant_id`) REFERENCES `mclaw_warrants`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_jail_decisions` (
    `id`                    INT AUTO_INCREMENT PRIMARY KEY,
    `suspect_citizenid`     VARCHAR(64) NOT NULL,
    `officer_citizenid`     VARCHAR(64) NOT NULL,
    `charges`               JSON NOT NULL,
    `proposed_jail_time`    INT NOT NULL,
    `proposed_fine`         INT NOT NULL DEFAULT 0,
    `decision`              ENUM('pending','accepted','rejected') DEFAULT 'pending',
    `decided_at`            TIMESTAMP NULL DEFAULT NULL,
    `file_id`               INT,
    `created_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `mclaw_attorneys` (
    `id`                    INT AUTO_INCREMENT PRIMARY KEY,
    `attorney_citizenid`    VARCHAR(64) NOT NULL,
    `client_citizenid`      VARCHAR(64) NOT NULL,
    `file_id`               INT,
    `scope`                 ENUM('general','file_based') DEFAULT 'file_based',
    `expires_at`            DATETIME NOT NULL,
    `granted_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `revoked_at`            TIMESTAMP NULL DEFAULT NULL,
    `is_active`             TINYINT DEFAULT 1,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_hearings` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`           INT NOT NULL,
    `judge_citizenid`   VARCHAR(64) NOT NULL,
    `type`              ENUM('physical','written') NOT NULL,
    `location`          JSON,
    `scheduled_at`      DATETIME NOT NULL,
    `started_at`        TIMESTAMP NULL DEFAULT NULL,
    `ended_at`          TIMESTAMP NULL DEFAULT NULL,
    `status`            ENUM('scheduled','active','completed','cancelled') DEFAULT 'scheduled',
    `notes`             TEXT,
    `created_at`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_verdicts` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`           INT NOT NULL UNIQUE,
    `hearing_id`        INT,
    `judge_citizenid`   VARCHAR(64) NOT NULL,
    `result`            ENUM('guilty','acquitted','dismissed') NOT NULL,
    `total_jail_time`   INT DEFAULT 0,
    `total_fine`        INT DEFAULT 0,
    `reasoning`         TEXT,
    `compensation_due`  INT DEFAULT 0,
    `created_at`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_compensation` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `verdict_id`    INT NOT NULL,
    `citizenid`     VARCHAR(64) NOT NULL,
    `amount`        INT NOT NULL,
    `reason`        TEXT,
    `paid`          TINYINT DEFAULT 0,
    `paid_at`       TIMESTAMP NULL DEFAULT NULL,
    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`verdict_id`) REFERENCES `mclaw_verdicts`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_confiscations` (
    `id`                    INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`               INT NOT NULL,
    `attorney_citizenid`    VARCHAR(64) NOT NULL,
    `owner_citizenid`       VARCHAR(64) NOT NULL,
    `asset_type`            ENUM('vehicle','property','cash','bank','item') NOT NULL,
    `asset_ref`             VARCHAR(128) NOT NULL,
    `asset_label`           VARCHAR(128),
    `impound_ref`           VARCHAR(128),
    `status`                ENUM('warning_sent','active','auction_pending','returned') DEFAULT 'warning_sent',
    `warning_sent_at`       TIMESTAMP NULL DEFAULT NULL,
    `executed_at`           TIMESTAMP NULL DEFAULT NULL,
    `created_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_auctions` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `confiscation_id`   INT NOT NULL,
    `opened_by`         VARCHAR(64) NOT NULL,
    `type`              ENUM('open_auction','sealed_bid','quick_sale','court_sale') NOT NULL,
    `min_bid`           INT NOT NULL DEFAULT 0,
    `buy_now_price`     INT,
    `winning_bid`       INT,
    `winner_citizenid`  VARCHAR(64),
    `status`            ENUM('listed','active','completed','cancelled') DEFAULT 'listed',
    `starts_at`         DATETIME NOT NULL,
    `ends_at`           DATETIME NOT NULL,
    `created_at`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`confiscation_id`) REFERENCES `mclaw_confiscations`(`id`)
);

CREATE TABLE IF NOT EXISTS `mclaw_notifications` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid`     VARCHAR(64) NOT NULL,
    `type`          ENUM('subpoena','warrant','power_of_attorney','hearing','verdict','confiscation','compensation') NOT NULL,
    `title`         VARCHAR(128) NOT NULL,
    `message`       TEXT NOT NULL,
    `ref_type`      VARCHAR(32),
    `ref_id`        INT,
    `is_read`       TINYINT DEFAULT 0,
    `read_at`       TIMESTAMP NULL DEFAULT NULL,
    `webhook_sent`  TINYINT DEFAULT 0,
    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `mclaw_webhook_log` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `notification_id`   INT,
    `citizenid`         VARCHAR(64),
    `event_type`        VARCHAR(64) NOT NULL,
    `payload`           JSON,
    `success`           TINYINT DEFAULT 0,
    `response_code`     SMALLINT,
    `sent_at`           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `mclaw_file_open_logs` (
    `id`                        INT AUTO_INCREMENT PRIMARY KEY,
    `file_id`                   INT NOT NULL,
    `action`                    ENUM('opened','approved','rejected') NOT NULL,
    `actioned_by_citizenid`     VARCHAR(64) NOT NULL,
    `actioned_by_job`           VARCHAR(50) NOT NULL,
    `notes`                     TEXT NULL,
    `created_at`                TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`file_id`) REFERENCES `mclaw_files`(`id`)
);
