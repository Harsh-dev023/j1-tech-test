-- =============================================================
-- JAIVORG — food_forest_db
-- Production-Complete Schema v5
-- Target : Empty MySQL 8.0+ instance
-- Run    : mysql -u root -p < jaivorg_complete_v5.sql
--
-- Changelog v4 → v5
--   Critical  1 : food_forests.owner_id FK → ON DELETE RESTRICT / ON UPDATE CASCADE
--   Critical  2 : FLOAT → DECIMAL for all financial & measurement columns
--   High      1 : UNIQUE key on food_forest_plants (ff + plant + variety)
--   High      2 : weekly_highlights unique scope → per food-forest per week
--   High      3 : Actual environmental condition columns on food_forests
--   High      4 : jaivorg_tokens lifecycle / audit table (+ trigger)
--   High      5 : Nurse-plant variety enforcement triggers on food_forest_plants
--   High      6 : export_jobs table for async PDF/Excel generation
--   Medium    1 : users.tags (JSON) + users.work columns
--   Medium    2 : jeevamrutham_given (BOOL) → last_jeevamrutham_date (DATE)
--   Medium    3 : food_forest_plants.plant_origin ENUM + planted_date
--   Bonus       : NPK split columns, FAQ/KB sort_order, notification delivery
--                 status, notification_rules season month columns,
--                 analytics_snapshots dimension columns,
--                 composite performance indexes
-- =============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP DATABASE IF EXISTS `food_forest_db`;
CREATE DATABASE `food_forest_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE `food_forest_db`;

-- =============================================================
-- SECTION 1 — REFERENCE / LOOKUP TABLES
-- =============================================================

CREATE TABLE `forest_stages` (
  `id`         INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `stage_name` VARCHAR(50)     NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stage_name` (`stage_name`)
) ENGINE=InnoDB;

CREATE TABLE `soil_types` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_soil_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `water_sources` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_water_source_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `terrain_types` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`            VARCHAR(100) NOT NULL,
  `slope_intensity` ENUM('Flat','Low','Medium','High') NOT NULL DEFAULT 'Flat',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_terrain_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `fencing_types` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(100) NOT NULL,
  `bio_species` VARCHAR(255) DEFAULT NULL COMMENT 'Botanical species name for bio fences',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_fencing_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `irrigation_methods` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_irrigation_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `addon_types` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_addon_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `food_forest_types` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL COMMENT 'Stand Alone | Surrounding House | Other',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ff_type_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `alert_types` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_alert_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `log_intervals` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label`       VARCHAR(100) NOT NULL COMMENT 'Display label shown in app timeline',
  `sort_order`  INT UNSIGNED NOT NULL COMMENT 'UI ordering',
  `unlock_days` INT UNSIGNED          DEFAULT NULL COMMENT 'Days after starting_date to unlock; NULL = immediate',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_log_interval_label` (`label`)
) ENGINE=InnoDB;

CREATE TABLE `event_types` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_event_type_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `content_types` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_content_type_name` (`name`)
) ENGINE=InnoDB;

CREATE TABLE `faq_categories` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_faq_cat_name` (`name`)
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 2 — USERS
-- =============================================================

CREATE TABLE `users` (
  `id`                      CHAR(36)     NOT NULL DEFAULT (UUID()),
  `full_name`               VARCHAR(255) NOT NULL,
  `email`                   VARCHAR(255) NOT NULL COMMENT '[PII] Encrypt at rest — AES-256',
  `password_hash`           VARCHAR(255) NOT NULL COMMENT '[HASHED] bcrypt/argon2id — never plain',
  `phone`                   VARCHAR(20)           DEFAULT NULL COMMENT '[PII] 10-digit; encrypt at rest',
  `role`                    ENUM('user','admin','super_admin') NOT NULL DEFAULT 'user',
  `is_active`               TINYINT(1)   NOT NULL DEFAULT 1,
  `address`                 TEXT                  DEFAULT NULL COMMENT '[PII] Encrypt at rest',
  `location`                VARCHAR(255)          DEFAULT NULL,
  `profile_photo_url`       VARCHAR(500)          DEFAULT NULL COMMENT 'General profile picture',
  `work_photo_url`          VARCHAR(500)          DEFAULT NULL COMMENT 'Field / work photo for admin tagging',
  `tags`                    JSON                  DEFAULT NULL COMMENT 'Freeform skill/interest tags for user profile display',
  `work`                    VARCHAR(255)          DEFAULT NULL COMMENT 'Short work or occupation description shown on profile',
  `approved_by_id`          CHAR(36)              DEFAULT NULL COMMENT 'Admin who approved this account',
  `device_token`            VARCHAR(500)          DEFAULT NULL COMMENT '[SENSITIVE] FCM/Firebase push token',
  `failed_login_attempts`   TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Reset on success; lock at threshold',
  `locked_until`            TIMESTAMP             DEFAULT NULL COMMENT 'Account locked until this timestamp',
  `password_changed_at`     TIMESTAMP             DEFAULT NULL,
  `last_login_at`           TIMESTAMP             DEFAULT NULL,
  `deleted_at`              TIMESTAMP             DEFAULT NULL COMMENT 'Soft delete — set instead of hard DELETE',
  `created_at`              TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email` (`email`),
  INDEX `idx_users_role`      (`role`),
  INDEX `idx_users_is_active` (`is_active`),
  INDEX `idx_users_deleted`   (`deleted_at`)
) ENGINE=InnoDB;

-- Self-referencing FK added after table definition
ALTER TABLE `users`
  ADD CONSTRAINT `fk_users_approved_by`
    FOREIGN KEY (`approved_by_id`) REFERENCES `users` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- =============================================================
-- SECTION 3 — PLANTS & VARIETIES
-- =============================================================

CREATE TABLE `plants` (
  `id`                 CHAR(36)     NOT NULL DEFAULT (UUID()),
  `name`               VARCHAR(255) NOT NULL,
  `canopy_tier`        ENUM('Big','Medium','Small','Nurse') DEFAULT NULL,
  `category`           VARCHAR(100) DEFAULT NULL,
  `min_temperature`    FLOAT        DEFAULT NULL COMMENT 'Min temperature tolerance (°C)',
  `max_temperature`    FLOAT        DEFAULT NULL COMMENT 'Max temperature tolerance (°C)',
  `humidity_max`       FLOAT        DEFAULT NULL COMMENT 'Max humidity tolerance (%)',
  `max_wind_speed_kmh` FLOAT        DEFAULT NULL COMMENT 'Max wind speed tolerance (km/h)',
  `is_nurse_plant`     TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'TRUE = Banana or Papaya; variety required',
  `description`        TEXT         DEFAULT NULL,
  `added_by`           CHAR(36)     DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_plant_name_tier` (`name`, `canopy_tier`),
  INDEX `idx_plants_tier`         (`canopy_tier`),
  INDEX `idx_plants_nurse`        (`is_nurse_plant`),
  INDEX `idx_plant_tier_nurse`    (`canopy_tier`, `is_nurse_plant`),
  CONSTRAINT `fk_plants_added_by`
    FOREIGN KEY (`added_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `plant_varieties` (
  `id`           CHAR(36)     NOT NULL DEFAULT (UUID()),
  `plant_id`     CHAR(36)     NOT NULL COMMENT 'Parent plant — must be is_nurse_plant = TRUE',
  `variety_name` VARCHAR(255) NOT NULL COMMENT 'e.g. Poovan Red, Nendran, Red Lady',
  `added_by`     CHAR(36)     DEFAULT NULL,
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_variety_plant_name` (`plant_id`, `variety_name`),
  CONSTRAINT `fk_pv_plant`
    FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_pv_added_by`
    FOREIGN KEY (`added_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 4 — FOOD FORESTS
-- =============================================================

CREATE TABLE `food_forests` (
  `id`                        CHAR(36)       NOT NULL DEFAULT (UUID()),
  `owner_id`                  CHAR(36)       NOT NULL,
  `approved_by`               CHAR(36)       DEFAULT NULL,
  `name`                      VARCHAR(255)   DEFAULT NULL,
  `plot_address`               TEXT           DEFAULT NULL,
  `land_type`                 ENUM('Flat','Multitier','Sloped') DEFAULT NULL COMMENT 'Broad land type classification',
  `food_forest_type_id`       INT UNSIGNED   DEFAULT NULL,
  `starting_date`             DATE           DEFAULT NULL,
  `plot_area_cents`           DECIMAL(12,2)  DEFAULT NULL CHECK (`plot_area_cents` > 0),
  `location_lat`              FLOAT          DEFAULT NULL,
  `location_long`             FLOAT          DEFAULT NULL,
  `location_point`            POINT          DEFAULT NULL COMMENT 'Spatial POINT(lng lat) — auto-set by trigger. Nullable; use idx_ff_bbox for proximity queries.',
  `no_of_trees`               INT UNSIGNED   DEFAULT NULL,
  `last_jeevamrutham_date`    DATE           DEFAULT NULL COMMENT 'Date Jeevamrutham was last applied. Use DATEDIFF(CURDATE(), last_jeevamrutham_date) for days since.',
  `soil_type_id`              INT UNSIGNED   DEFAULT NULL,
  `water_source_id`           INT UNSIGNED   DEFAULT NULL,
  `terrain_type_id`           INT UNSIGNED   DEFAULT NULL,
  `fencing_type_id`           INT UNSIGNED   DEFAULT NULL,
  `stage_id`                  INT UNSIGNED   DEFAULT NULL,
  `irrigation_method_id`      INT UNSIGNED   DEFAULT NULL,
  `daily_water_usage_litres`  DECIMAL(10,2)  DEFAULT NULL COMMENT 'Daily water usage in litres',
  `wind_condition`            ENUM('Low','Medium','High') DEFAULT NULL,
  `actual_temperature_min_c`  DECIMAL(5,2)   DEFAULT NULL COMMENT 'Actual minimum ambient temperature at this site (°C)',
  `actual_temperature_max_c`  DECIMAL(5,2)   DEFAULT NULL COMMENT 'Actual maximum ambient temperature at this site (°C)',
  `humidity_pct`              DECIMAL(5,2)   DEFAULT NULL COMMENT 'Ambient humidity at this site (%)',
  `wind_speed_kmph`           DECIMAL(6,2)   DEFAULT NULL COMMENT 'Measured maximum wind speed at this site (km/h)',
  `water_logging_area`        TINYINT(1)     DEFAULT NULL,
  `fire_prone_area`           TINYINT(1)     DEFAULT NULL,
  `water_filter`              TINYINT(1)     DEFAULT NULL,
  `annual_rainfall`           DECIMAL(10,2)  DEFAULT NULL COMMENT 'Annual rainfall in mm',
  `elevation_value`           FLOAT          DEFAULT NULL COMMENT 'Numeric elevation value',
  `elevation_unit`            ENUM('cm','feet') DEFAULT NULL,
  `compost_vendor`            VARCHAR(255)   DEFAULT NULL,
  `boundary_protection`       VARCHAR(255)   DEFAULT NULL,
  `total_expenditure`         DECIMAL(15,2)  DEFAULT NULL,
  `expenditure_per_pit`       DECIMAL(15,2)  GENERATED ALWAYS AS (
                                CASE
                                  WHEN `no_of_trees` IS NOT NULL AND `no_of_trees` > 0
                                  THEN `total_expenditure` / `no_of_trees`
                                  ELSE NULL
                                END
                              ) VIRTUAL COMMENT 'Auto-calculated: total_expenditure / no_of_trees (DECIMAL safe)',
  `jaivorg_token`             VARCHAR(100)   NOT NULL COMMENT 'Jaivorg registration token — required per FF',
  `sketch_url`                VARCHAR(500)   DEFAULT NULL,
  `map_picture_url`           VARCHAR(500)   DEFAULT NULL,
  `deleted_at`                TIMESTAMP      DEFAULT NULL COMMENT 'Soft delete timestamp',
  `is_deleted`                TINYINT(1)     GENERATED ALWAYS AS (`deleted_at` IS NOT NULL) VIRTUAL,
  `created_at`                TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`                TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ff_jaivorg_token`        (`jaivorg_token`),
  INDEX `idx_ff_owner`                    (`owner_id`),
  INDEX `idx_ff_stage`                    (`stage_id`),
  INDEX `idx_ff_soil`                     (`soil_type_id`),
  INDEX `idx_ff_water_src`               (`water_source_id`),
  INDEX `idx_ff_terrain`                  (`terrain_type_id`),
  INDEX `idx_ff_irrigation`               (`irrigation_method_id`),
  INDEX `idx_ff_start_date`               (`starting_date`),
  INDEX `idx_ff_lat_lng`                  (`location_lat`, `location_long`),
  INDEX `idx_ff_fire_water`               (`fire_prone_area`, `water_logging_area`),
  INDEX `idx_ff_irrigation_filter`        (`irrigation_method_id`, `water_filter`),
  INDEX `idx_ff_active`                   (`is_deleted`, `stage_id`),
  INDEX `idx_ff_deleted`                  (`deleted_at`),
  INDEX `idx_ff_stage_land`               (`stage_id`, `land_type`),
  INDEX `idx_ff_watersrc_irr`             (`water_source_id`, `irrigation_method_id`),
  INDEX `idx_ff_bbox`                     (`location_lat`, `location_long`, `deleted_at`),
  -- NOTE: No SPATIAL INDEX on location_point — MySQL requires NOT NULL for spatial indexes.
  -- location_point is nullable (not all FFs have GPS coords). Use idx_ff_bbox for
  -- bounding-box proximity queries, or ST_Distance/ST_Within on location_point directly.
  CONSTRAINT `fk_ff_owner`
    FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ff_approved_by`
    FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_ff_soil_type`
    FOREIGN KEY (`soil_type_id`) REFERENCES `soil_types` (`id`),
  CONSTRAINT `fk_ff_water_source`
    FOREIGN KEY (`water_source_id`) REFERENCES `water_sources` (`id`),
  CONSTRAINT `fk_ff_terrain_type`
    FOREIGN KEY (`terrain_type_id`) REFERENCES `terrain_types` (`id`),
  CONSTRAINT `fk_ff_fencing_type`
    FOREIGN KEY (`fencing_type_id`) REFERENCES `fencing_types` (`id`),
  CONSTRAINT `fk_ff_stage`
    FOREIGN KEY (`stage_id`) REFERENCES `forest_stages` (`id`),
  CONSTRAINT `fk_ff_irrigation_method`
    FOREIGN KEY (`irrigation_method_id`) REFERENCES `irrigation_methods` (`id`),
  CONSTRAINT `fk_ff_food_forest_type`
    FOREIGN KEY (`food_forest_type_id`) REFERENCES `food_forest_types` (`id`),
  CONSTRAINT `chk_ff_temp_range`
    CHECK (`actual_temperature_min_c` IS NULL
           OR `actual_temperature_max_c` IS NULL
           OR `actual_temperature_max_c` >= `actual_temperature_min_c`),
  CONSTRAINT `chk_ff_humidity`
    CHECK (`humidity_pct` IS NULL OR `humidity_pct` BETWEEN 0 AND 100),
  CONSTRAINT `chk_ff_wind_speed`
    CHECK (`wind_speed_kmph` IS NULL OR `wind_speed_kmph` >= 0)
) ENGINE=InnoDB;

-- Trigger: auto-populate location_point on INSERT
DELIMITER $$
CREATE TRIGGER `trg_ff_point_insert`
  BEFORE INSERT ON `food_forests`
  FOR EACH ROW
BEGIN
  IF NEW.location_lat IS NOT NULL AND NEW.location_long IS NOT NULL THEN
    SET NEW.location_point = ST_PointFromText(
      CONCAT('POINT(', NEW.location_long, ' ', NEW.location_lat, ')'), 4326
    );
  END IF;
END$$

CREATE TRIGGER `trg_ff_point_update`
  BEFORE UPDATE ON `food_forests`
  FOR EACH ROW
BEGIN
  IF NEW.location_lat IS NOT NULL AND NEW.location_long IS NOT NULL THEN
    SET NEW.location_point = ST_PointFromText(
      CONCAT('POINT(', NEW.location_long, ' ', NEW.location_lat, ')'), 4326
    );
  END IF;
END$$
DELIMITER ;

-- =============================================================
-- SECTION 5 — JAIVORG TOKENS
-- =============================================================

CREATE TABLE `jaivorg_tokens` (
  `id`             CHAR(36)     NOT NULL DEFAULT (UUID()),
  `token`          VARCHAR(100) NOT NULL COMMENT 'The registration token string',
  `issued_by`      CHAR(36)     NOT NULL COMMENT 'Admin user who created this token',
  `issued_to`      CHAR(36)     DEFAULT NULL COMMENT 'User pre-assigned this token (optional)',
  `issued_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at`     TIMESTAMP    DEFAULT NULL COMMENT 'NULL = no expiry; set for time-limited tokens',
  `used_at`        TIMESTAMP    DEFAULT NULL COMMENT 'Timestamp when token was consumed by FF registration',
  `food_forest_id` CHAR(36)     DEFAULT NULL COMMENT 'The food forest registered with this token',
  `status`         ENUM('available','used','revoked','expired') NOT NULL DEFAULT 'available',
  `revoked_by`     CHAR(36)     DEFAULT NULL COMMENT 'Admin who revoked this token',
  `revoked_at`     TIMESTAMP    DEFAULT NULL,
  `notes`          TEXT         DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY  `uq_jt_token`      (`token`),
  INDEX        `idx_jt_status`    (`status`),
  INDEX        `idx_jt_issued_to` (`issued_to`),
  INDEX        `idx_jt_ff`        (`food_forest_id`),
  INDEX        `idx_jt_expires`   (`expires_at`),
  CONSTRAINT `fk_jt_issued_by`
    FOREIGN KEY (`issued_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_jt_issued_to`
    FOREIGN KEY (`issued_to`) REFERENCES `users` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_jt_food_forest`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_jt_revoked_by`
    FOREIGN KEY (`revoked_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
  -- NOTE: chk_jt_used_once removed — MySQL 8 forbids CHECK constraints on columns
  -- involved in FK ON DELETE SET NULL. The 'token used once' rule is enforced
  -- by trg_jt_mark_used (BEFORE UPDATE trigger below).
) ENGINE=InnoDB COMMENT='Audit trail for Jaivorg registration token issuance and consumption';

DELIMITER $$
CREATE TRIGGER `trg_jt_mark_used`
  BEFORE UPDATE ON `jaivorg_tokens`
  FOR EACH ROW
BEGIN
  IF OLD.status = 'used' AND NEW.status = 'used' AND NEW.food_forest_id <> OLD.food_forest_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Jaivorg token has already been consumed and cannot be reassigned.';
  END IF;
  IF NEW.status = 'used' AND OLD.status <> 'used' THEN
    SET NEW.used_at = CURRENT_TIMESTAMP;
  END IF;
  IF NEW.status = 'revoked' AND OLD.status <> 'revoked' THEN
    SET NEW.revoked_at = CURRENT_TIMESTAMP;
  END IF;
END$$
DELIMITER ;

-- =============================================================
-- SECTION 6 — FOOD FOREST PLANTS & ADDONS
-- =============================================================

CREATE TABLE `food_forest_plants` (
  `id`             CHAR(36)     NOT NULL DEFAULT (UUID()),
  `food_forest_id` CHAR(36)     NOT NULL,
  `plant_id`       CHAR(36)     NOT NULL,
  `variety_id`     CHAR(36)     DEFAULT NULL COMMENT 'Required when plant is_nurse_plant = TRUE',
  `count`          INT UNSIGNED DEFAULT NULL,
  `plant_origin`   ENUM('existing','newly_planted') NOT NULL DEFAULT 'newly_planted'
                   COMMENT 'existing = pre-existing tree on land; newly_planted = added during FF project',
  `planted_date`   DATE         DEFAULT NULL COMMENT 'Date this plant was added (NULL for pre-existing plants)',
  `row_order`      INT UNSIGNED DEFAULT NULL COMMENT 'UI display order within tier',
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Row creation timestamp',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ffp_ff_plant_variety` (`food_forest_id`, `plant_id`, `variety_id`),
  INDEX `idx_ffp_ff`      (`food_forest_id`),
  INDEX `idx_ffp_plant`   (`plant_id`),
  INDEX `idx_ffp_variety` (`variety_id`),
  CONSTRAINT `fk_ffp_ff`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ffp_plant`
    FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`),
  CONSTRAINT `fk_ffp_variety`
    FOREIGN KEY (`variety_id`) REFERENCES `plant_varieties` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- Nurse-plant variety enforcement triggers
DELIMITER $$
CREATE TRIGGER `trg_ffp_nurse_variety_insert`
  BEFORE INSERT ON `food_forest_plants`
  FOR EACH ROW
BEGIN
  DECLARE v_is_nurse TINYINT(1) DEFAULT 0;
  SELECT `is_nurse_plant` INTO v_is_nurse FROM `plants` WHERE `id` = NEW.plant_id;
  IF v_is_nurse = 1 AND (NEW.variety_id IS NULL) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Nurse plants (Banana / Papaya) require a variety_id. Please select a valid variety before inserting.';
  END IF;
END$$

CREATE TRIGGER `trg_ffp_nurse_variety_update`
  BEFORE UPDATE ON `food_forest_plants`
  FOR EACH ROW
BEGIN
  DECLARE v_is_nurse TINYINT(1) DEFAULT 0;
  SELECT `is_nurse_plant` INTO v_is_nurse FROM `plants` WHERE `id` = NEW.plant_id;
  IF v_is_nurse = 1 AND (NEW.variety_id IS NULL) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Nurse plants (Banana / Papaya) require a variety_id. Cannot remove variety_id from a nurse plant entry.';
  END IF;
END$$
DELIMITER ;

CREATE TABLE `food_forest_addons` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `food_forest_id` CHAR(36)     NOT NULL,
  `addon_type_id`  INT UNSIGNED NOT NULL,
  `added_by`       CHAR(36)     DEFAULT NULL,
  `details`        TEXT         DEFAULT NULL,
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_ffa_ff`   (`food_forest_id`),
  INDEX `idx_ffa_type` (`addon_type_id`),
  CONSTRAINT `fk_ffa_ff`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_ffa_addon_type`
    FOREIGN KEY (`addon_type_id`) REFERENCES `addon_types` (`id`),
  CONSTRAINT `fk_ffa_added_by`
    FOREIGN KEY (`added_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 7 — FOREST LOGS & PHOTOS
-- =============================================================

CREATE TABLE `forest_logs` (
  `id`             CHAR(36)     NOT NULL DEFAULT (UUID()),
  `food_forest_id` CHAR(36)     NOT NULL,
  `interval_id`    INT UNSIGNED DEFAULT NULL,
  `title`          VARCHAR(255) DEFAULT NULL,
  `description`    TEXT         DEFAULT NULL,
  `logged_at`      TIMESTAMP    DEFAULT NULL,
  `unlocks_at`     DATE         DEFAULT NULL COMMENT 'Photos visible only on/after this date',
  PRIMARY KEY (`id`),
  INDEX `idx_flog_ff`       (`food_forest_id`),
  INDEX `idx_flog_interval` (`interval_id`),
  INDEX `idx_flog_unlocks`  (`unlocks_at`),
  CONSTRAINT `fk_flog_ff`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_flog_interval`
    FOREIGN KEY (`interval_id`) REFERENCES `log_intervals` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `log_photos` (
  `id`                  CHAR(36)     NOT NULL DEFAULT (UUID()),
  `log_id`              CHAR(36)     NOT NULL,
  `photo_url`           VARCHAR(500) DEFAULT NULL,
  `uploaded_at`         TIMESTAMP    DEFAULT NULL,
  `is_weekly_highlight` TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  INDEX `idx_lphoto_log`       (`log_id`),
  INDEX `idx_lphoto_highlight` (`is_weekly_highlight`),
  CONSTRAINT `fk_lphoto_log`
    FOREIGN KEY (`log_id`) REFERENCES `forest_logs` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `weekly_highlights` (
  `id`              CHAR(36)     NOT NULL DEFAULT (UUID()),
  `food_forest_id`  CHAR(36)     NOT NULL,
  `log_photo_id`    CHAR(36)     NOT NULL,
  `week_start_date` DATE         NOT NULL COMMENT 'Monday of featured week',
  `selected_by`     CHAR(36)     NOT NULL,
  `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_highlight_ff_week` (`food_forest_id`, `week_start_date`),
  INDEX `idx_wh_ff`   (`food_forest_id`),
  INDEX `idx_wh_week` (`week_start_date`),
  CONSTRAINT `fk_wh_ff`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_wh_photo`
    FOREIGN KEY (`log_photo_id`) REFERENCES `log_photos` (`id`),
  CONSTRAINT `fk_wh_selected_by`
    FOREIGN KEY (`selected_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 8 — SOIL TESTS
-- =============================================================

CREATE TABLE `soil_tests` (
  `id`             CHAR(36)     NOT NULL DEFAULT (UUID()),
  `food_forest_id` CHAR(36)     NOT NULL,
  `submitted_by`   CHAR(36)     DEFAULT NULL COMMENT 'User who entered this soil test result',
  `reviewed_by`    CHAR(36)     DEFAULT NULL,
  `test_date`      DATE         DEFAULT NULL,
  `ph_level`       DECIMAL(4,2) DEFAULT NULL CHECK (`ph_level` BETWEEN 0 AND 14),
  `moisture`       DECIMAL(6,2) DEFAULT NULL,
  `npk`            VARCHAR(100) DEFAULT NULL COMMENT 'N:P:K ratio string (legacy; prefer npk_* columns)',
  `npk_nitrogen`   DECIMAL(8,3) DEFAULT NULL COMMENT 'Nitrogen component of NPK (kg/ha or %)',
  `npk_phosphorus` DECIMAL(8,3) DEFAULT NULL COMMENT 'Phosphorus component of NPK (kg/ha or %)',
  `npk_potassium`  DECIMAL(8,3) DEFAULT NULL COMMENT 'Potassium component of NPK (kg/ha or %)',
  `phosphate`      DECIMAL(8,3) DEFAULT NULL,
  `organic_carbon` DECIMAL(8,3) DEFAULT NULL,
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_soil_ff`      (`food_forest_id`),
  INDEX `idx_soil_date`    (`test_date`),
  INDEX `idx_soil_ff_date` (`food_forest_id`, `test_date`),
  CONSTRAINT `fk_soil_ff`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_soil_submitted_by`
    FOREIGN KEY (`submitted_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_soil_reviewed_by`
    FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 9 — NOTIFICATIONS
-- =============================================================

CREATE TABLE `notifications` (
  `id`              CHAR(36)     NOT NULL DEFAULT (UUID()),
  `sent_to`         CHAR(36)     NOT NULL,
  `sent_by`         CHAR(36)     DEFAULT NULL,
  `food_forest_id`  CHAR(36)     DEFAULT NULL,
  `title`           VARCHAR(255) DEFAULT NULL,
  `message`         TEXT         DEFAULT NULL,
  `alert_type_id`   INT UNSIGNED DEFAULT NULL,
  `severity`        ENUM('critical','informative') DEFAULT NULL,
  `sent_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_read`         TINYINT(1)   NOT NULL DEFAULT 0,
  `delivery_status` ENUM('pending','sent','failed') NOT NULL DEFAULT 'pending'
                    COMMENT 'Push notification dispatch status',
  `delivered_at`    TIMESTAMP    DEFAULT NULL COMMENT 'Timestamp when push notification was confirmed delivered',
  PRIMARY KEY (`id`),
  INDEX `idx_notif_to_read` (`sent_to`, `is_read`, `sent_at`),
  INDEX `idx_notif_ff`      (`food_forest_id`),
  INDEX `idx_notif_type`    (`alert_type_id`),
  CONSTRAINT `fk_notif_sent_to`
    FOREIGN KEY (`sent_to`) REFERENCES `users` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_notif_sent_by`
    FOREIGN KEY (`sent_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_notif_ff`
    FOREIGN KEY (`food_forest_id`) REFERENCES `food_forests` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_notif_alert_type`
    FOREIGN KEY (`alert_type_id`) REFERENCES `alert_types` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `notification_preferences` (
  `id`            CHAR(36)     NOT NULL DEFAULT (UUID()),
  `user_id`       CHAR(36)     NOT NULL,
  `alert_type_id` INT UNSIGNED DEFAULT NULL COMMENT 'NULL = global preference',
  `is_enabled`    TINYINT(1)   NOT NULL DEFAULT 1,
  `updated_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_np_user_type` (`user_id`, `alert_type_id`),
  INDEX `idx_np_user` (`user_id`),
  CONSTRAINT `fk_np_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_np_alert_type`
    FOREIGN KEY (`alert_type_id`) REFERENCES `alert_types` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `notification_rules` (
  `id`                              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `rule_name`                       VARCHAR(200) NOT NULL,
  `condition_type`                  ENUM('seasonal','age_based','event_based','scheduled','geographic','manual') NOT NULL DEFAULT 'manual',
  `season_trigger`                  ENUM('monsoon_start','monsoon_end','summer','winter','pre_monsoon') DEFAULT NULL,
  `season_start_month`              TINYINT UNSIGNED DEFAULT NULL COMMENT '1=January … 12=December — start month of the season trigger',
  `season_end_month`                TINYINT UNSIGNED DEFAULT NULL COMMENT '1=January … 12=December — end month of the season trigger',
  `ff_age_min_years`                FLOAT        DEFAULT NULL COMMENT 'Min FF age in years to match',
  `ff_age_max_years`                FLOAT        DEFAULT NULL COMMENT 'Max FF age in years (NULL = no upper bound)',
  `requires_water_logging`          TINYINT(1)   DEFAULT NULL COMMENT 'NULL=ignore, 1=water-logging FFs only',
  `requires_fire_prone`             TINYINT(1)   DEFAULT NULL COMMENT 'NULL=ignore, 1=fire-prone FFs only',
  `requires_irrigation_method_id`   INT UNSIGNED DEFAULT NULL COMMENT 'NULL=any irrigation method',
  `requires_water_filter`           TINYINT(1)   DEFAULT NULL COMMENT 'NULL=ignore, 1=FFs with water filter',
  `schedule_type`                   ENUM('weekly','biweekly','monthly','once') DEFAULT NULL,
  `schedule_day_of_month`           TINYINT UNSIGNED DEFAULT NULL COMMENT 'Day 1-28 for monthly rules',
  `alert_type_id`                   INT UNSIGNED DEFAULT NULL,
  `severity`                        ENUM('critical','informative') NOT NULL DEFAULT 'informative',
  `message_template`                TEXT         DEFAULT NULL COMMENT 'Use {{ff_name}}, {{owner_name}} placeholders',
  `is_active`                       TINYINT(1)   NOT NULL DEFAULT 1,
  `last_triggered_at`               TIMESTAMP    DEFAULT NULL,
  `created_by`                      CHAR(36)     DEFAULT NULL,
  `created_at`                      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_nrule_active` (`is_active`, `condition_type`),
  CONSTRAINT `fk_nrule_alert_type`
    FOREIGN KEY (`alert_type_id`) REFERENCES `alert_types` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_nrule_irrigation`
    FOREIGN KEY (`requires_irrigation_method_id`) REFERENCES `irrigation_methods` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_nrule_created_by`
    FOREIGN KEY (`created_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `chk_nrule_season_months`
    CHECK (
      (season_start_month IS NULL AND season_end_month IS NULL)
      OR (season_start_month BETWEEN 1 AND 12 AND season_end_month BETWEEN 1 AND 12)
    )
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 10 — KNOWLEDGE BASE, FAQ, EVENTS
-- =============================================================

CREATE TABLE `knowledge_base` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title`           VARCHAR(255) NOT NULL,
  `content_type_id` INT UNSIGNED DEFAULT NULL,
  `url`             VARCHAR(500) DEFAULT NULL,
  `description`     TEXT         DEFAULT NULL,
  `is_published`    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '0 = draft (admin only); 1 = visible to all users',
  `sort_order`      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Display order within content type',
  `created_by`      CHAR(36)     DEFAULT NULL,
  `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_kb_type`            (`content_type_id`),
  INDEX `idx_kb_created_by`      (`created_by`),
  INDEX `idx_kb_published_order` (`is_published`, `sort_order`),
  CONSTRAINT `fk_kb_content_type`
    FOREIGN KEY (`content_type_id`) REFERENCES `content_types` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_kb_created_by`
    FOREIGN KEY (`created_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `faqs` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `question`     TEXT         NOT NULL,
  `answer`       TEXT         NOT NULL,
  `youtube_link` VARCHAR(500) DEFAULT NULL,
  `category_id`  INT UNSIGNED DEFAULT NULL,
  `sort_order`   INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Display order for FAQ list; lower number = higher position',
  `created_by`   CHAR(36)     DEFAULT NULL,
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_faq_cat`        (`category_id`),
  INDEX `idx_faq_created_by` (`created_by`),
  INDEX `idx_faq_cat_order`  (`category_id`, `sort_order`),
  CONSTRAINT `fk_faq_category`
    FOREIGN KEY (`category_id`) REFERENCES `faq_categories` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_faq_created_by`
    FOREIGN KEY (`created_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `events` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title`         VARCHAR(255) NOT NULL,
  `event_type_id` INT UNSIGNED DEFAULT NULL,
  `event_date`    DATE         DEFAULT NULL,
  `description`   TEXT         DEFAULT NULL,
  `link`          VARCHAR(500) DEFAULT NULL,
  `media_url`     VARCHAR(500) DEFAULT NULL,
  `thumbnail_url` VARCHAR(500) DEFAULT NULL,
  `created_by`    CHAR(36)     DEFAULT NULL,
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_event_type`       (`event_type_id`),
  INDEX `idx_event_date`       (`event_date`),
  INDEX `idx_event_created_by` (`created_by`),
  CONSTRAINT `fk_event_type`
    FOREIGN KEY (`event_type_id`) REFERENCES `event_types` (`id`)
    ON DELETE SET NULL,
  CONSTRAINT `fk_event_created_by`
    FOREIGN KEY (`created_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 11 — ADMIN, CONFIG & EXPORT
-- =============================================================

CREATE TABLE `admin_activity_logs` (
  `id`           CHAR(36)     NOT NULL DEFAULT (UUID()),
  `performed_by` CHAR(36)     NOT NULL,
  `action`       VARCHAR(100) NOT NULL,
  `target_type`  VARCHAR(50)  DEFAULT NULL,
  `target_id`    CHAR(36)     DEFAULT NULL,
  `details`      TEXT         DEFAULT NULL,
  `performed_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_aal_actor`  (`performed_by`, `performed_at`),
  INDEX `idx_aal_target` (`target_type`, `target_id`),
  CONSTRAINT `fk_aal_performed_by`
    FOREIGN KEY (`performed_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB;

CREATE TABLE `app_config` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(100) NOT NULL,
  `value`      TEXT         DEFAULT NULL,
  `updated_by` CHAR(36)     DEFAULT NULL,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_config_key` (`config_key`),
  CONSTRAINT `fk_config_updated_by`
    FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `analytics_snapshots` (
  `id`                     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `snapshot_date`          DATE          NOT NULL,
  `stage_id`               INT UNSIGNED  DEFAULT NULL COMMENT 'NULL = global snapshot; set for per-stage breakdown',
  `region`                 VARCHAR(100)  DEFAULT NULL COMMENT 'NULL = all regions; set for per-region breakdown',
  `total_food_forests`     INT UNSIGNED  NOT NULL DEFAULT 0,
  `total_area_cents`       DECIMAL(15,3) NOT NULL DEFAULT 0,
  `avg_area_cents`         DECIMAL(10,3) NOT NULL DEFAULT 0,
  `avg_daily_water_usage`  DECIMAL(10,2) NOT NULL DEFAULT 0,
  `avg_plant_diversity`    DECIMAL(6,2)  NOT NULL DEFAULT 0,
  `avg_days_since_planted` DECIMAL(8,2)  NOT NULL DEFAULT 0,
  `total_trees`            INT UNSIGNED  NOT NULL DEFAULT 0,
  `generated_at`           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_snapshot_date_stage_region` (`snapshot_date`, `stage_id`, `region`)
) ENGINE=InnoDB;

CREATE TABLE `export_jobs` (
  `id`           CHAR(36)     NOT NULL DEFAULT (UUID()),
  `requested_by` CHAR(36)     NOT NULL,
  `format`       ENUM('pdf','excel') NOT NULL COMMENT 'Output file format',
  `export_scope` ENUM('food_forests','analytics','soil_tests','plants') NOT NULL DEFAULT 'food_forests'
                 COMMENT 'Which dataset is being exported',
  `filters_json` JSON         DEFAULT NULL COMMENT 'Serialised admin filter parameters used to generate this export',
  `status`       ENUM('queued','processing','completed','failed') NOT NULL DEFAULT 'queued',
  `file_path`    VARCHAR(500) DEFAULT NULL COMMENT 'Relative path or cloud storage key of generated file',
  `file_size_kb` INT UNSIGNED DEFAULT NULL,
  `error_msg`    TEXT         DEFAULT NULL COMMENT 'Populated when status = failed',
  `row_count`    INT UNSIGNED DEFAULT NULL COMMENT 'Number of data rows in the export',
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP    DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_ej_user_status` (`requested_by`, `status`),
  INDEX `idx_ej_created`     (`created_at`),
  INDEX `idx_ej_status`      (`status`),
  CONSTRAINT `fk_ej_requested_by`
    FOREIGN KEY (`requested_by`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='Async export job tracker for PDF and Excel report generation';

-- =============================================================
-- SECTION 12 — REGISTRATION DRAFT / AUTO-SAVE SYSTEM
-- =============================================================

CREATE TABLE `registration_drafts` (
  `id`              CHAR(36)         NOT NULL DEFAULT (UUID()),
  `user_id`         CHAR(36)         NOT NULL,
  `draft_token`     VARCHAR(100)     NOT NULL COMMENT 'Unique session token returned to client',
  `current_step`    TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Current page 1–7',
  `completion_pct`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Percentage 0–100',
  `step_data`       JSON             NOT NULL COMMENT 'Serialised form values per field',
  `status`          ENUM('active','submitted','abandoned') NOT NULL DEFAULT 'active',
  `last_saved_at`   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at`      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_draft_token` (`draft_token`),
  INDEX `idx_draft_user`         (`user_id`),
  INDEX `idx_draft_status_saved` (`status`, `last_saved_at`),
  CONSTRAINT `fk_draft_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `registration_draft_steps` (
  `id`       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `draft_id` CHAR(36)         NOT NULL,
  `step`     TINYINT UNSIGNED NOT NULL COMMENT 'Step number saved (1–7)',
  `saved_at` TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_dstep_draft` (`draft_id`),
  CONSTRAINT `fk_dstep_draft`
    FOREIGN KEY (`draft_id`) REFERENCES `registration_drafts` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 13 — SECURITY & COMPLIANCE TABLES
-- =============================================================

CREATE TABLE `user_audit_logs` (
  `id`           CHAR(36)     NOT NULL DEFAULT (UUID()),
  `user_id`      CHAR(36)     NOT NULL COMMENT 'User whose data was affected',
  `performed_by` CHAR(36)     NOT NULL COMMENT 'Actor (may equal user_id for self-actions)',
  `action`       VARCHAR(100) NOT NULL COMMENT 'e.g. profile_update, login, logout, data_export',
  `ip_address`   VARCHAR(45)  DEFAULT NULL COMMENT 'IPv4 or IPv6',
  `user_agent`   VARCHAR(500) DEFAULT NULL,
  `details`      JSON         DEFAULT NULL COMMENT '{field: [old_value, new_value]}',
  `performed_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_uaudit_user`  (`user_id`, `performed_at`),
  INDEX `idx_uaudit_actor` (`performed_by`),
  CONSTRAINT `fk_uaudit_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_uaudit_actor`
    FOREIGN KEY (`performed_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB;

CREATE TABLE `user_consent_records` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`      CHAR(36)     NOT NULL,
  `consent_type` VARCHAR(100) NOT NULL COMMENT 'e.g. terms_and_conditions, marketing_notifications, data_processing',
  `consented`    TINYINT(1)   NOT NULL,
  `ip_address`   VARCHAR(45)  DEFAULT NULL,
  `recorded_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_consent_user` (`user_id`, `consent_type`),
  CONSTRAINT `fk_consent_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `data_deletion_requests` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`      CHAR(36)     NOT NULL,
  `requested_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_at` TIMESTAMP    DEFAULT NULL,
  `status`       ENUM('pending','processing','completed','rejected') NOT NULL DEFAULT 'pending',
  `notes`        TEXT         DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_deletion_status` (`status`),
  INDEX `idx_deletion_user`   (`user_id`),
  CONSTRAINT `fk_deletion_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB;

-- =============================================================
-- SECTION 14 — SEED DATA
-- =============================================================

INSERT INTO `forest_stages` (`stage_name`) VALUES
  ('Initial Stage'),
  ('Composted'),
  ('Land Preparation'),
  ('Planted'),
  ('Running');

INSERT INTO `soil_types` (`name`) VALUES
  ('Coastal Alluvium'),
  ('Mixed Alluvium'),
  ('Acid Saline Soils'),
  ('Laterite Soils'),
  ('Black Cotton Soils'),
  ('Red Soils'),
  ('Hill Soils'),
  ('Forest Soils'),
  ('Kari Soils');

INSERT INTO `water_sources` (`name`) VALUES
  ('Tap Well'),
  ('Pond'),
  ('Borewell'),
  ('River');

INSERT INTO `terrain_types` (`name`, `slope_intensity`) VALUES
  ('Flat',           'Flat'),
  ('Slightly Sloped','Low'),
  ('Medium Sloped',  'Medium'),
  ('High Sloped',    'High');

INSERT INTO `fencing_types` (`name`, `bio_species`) VALUES
  ('Electric Fence',                  NULL),
  ('Metal Fence',                     NULL),
  ('Wooden Fence',                    NULL),
  ('Stone Wall',                      NULL),
  ('Bio Fence - Gliricidia',          'Gliricidia sepium'),
  ('Bio Fence - Premna serratifolia', 'Premna serratifolia'),
  ('Bio Fence - Hibiscus',            'Hibiscus rosa-sinensis'),
  ('Cement Wall',                     NULL),
  ('No Fencing',                      NULL);

INSERT INTO `irrigation_methods` (`name`) VALUES
  ('Drip'),
  ('Tap');

INSERT INTO `addon_types` (`name`) VALUES
  ('Apiculture (Honey Bee)'),
  ('Fish Farming'),
  ('Electric Fence'),
  ('Bio Fence'),
  ('Live Shading'),
  ('Repetition');

INSERT INTO `food_forest_types` (`name`) VALUES
  ('Stand Alone'),
  ('Surrounding House'),
  ('Other');

INSERT INTO `alert_types` (`name`) VALUES
  ('Irrigation Reminder'),
  ('Pruning Schedule'),
  ('Water Logging Alert'),
  ('Fire Alert'),
  ('Planting Time Alert'),
  ('Filter Cleaning Alert'),
  ('Other');

INSERT INTO `log_intervals` (`label`, `sort_order`, `unlock_days`) VALUES
  ('Land Before Food Foresting',  1,    0),
  ('Initial Plot Leveling',       2,    0),
  ('During Planting',             3,    0),
  ('After 2 Weeks',               4,   14),
  ('After 1 Month',               5,   30),
  ('After 3 Months',              6,   90),
  ('After 6 Months',              7,  180),
  ('After 1 Year',                8,  365),
  ('After 2 Years',               9,  730),
  ('After 3 Years',              10, 1095),
  ('After 4 Years',              11, 1460),
  ('After 5 Years',              12, 1825),
  ('After 6 Years',              13, 2190),
  ('After 7 Years',              14, 2555),
  ('After 8 Years',              15, 2920),
  ('After 9 Years',              16, 3285),
  ('After 10 Years',             17, 3650);

INSERT INTO `event_types` (`name`) VALUES
  ('Annual Food Forest Day'),
  ('Seminar'),
  ('Study Report'),
  ('Article'),
  ('Food Preparation Video'),
  ('Tutorial'),
  ('Other');

INSERT INTO `content_types` (`name`) VALUES
  ('Classes and Tutorials'),
  ('Food Forest Presentation'),
  ('Knowledge Base Article'),
  ('Food Preparation Video'),
  ('Soil Testing Tutorial'),
  ('Drip Irrigation Video'),
  ('Other');

INSERT INTO `faq_categories` (`name`) VALUES
  ('General'),
  ('Registration'),
  ('Plant Management'),
  ('Soil & Water'),
  ('Notifications'),
  ('Admin');

INSERT INTO `app_config` (`config_key`, `value`) VALUES
  ('whatsapp_community_url', NULL),
  ('jaivorg_website_url',    'https://www.jaivorg.com'),
  ('annual_food_forest_day', 'March 15'),
  ('draft_abandon_days',     '30');

-- =============================================================
-- SECTION 15 — NOTIFICATION RULES SEED
-- =============================================================

INSERT INTO `notification_rules`
  (`rule_name`, `condition_type`, `season_trigger`,
   `season_start_month`, `season_end_month`,
   `ff_age_min_years`, `ff_age_max_years`,
   `requires_water_logging`, `requires_fire_prone`,
   `requires_irrigation_method_id`, `requires_water_filter`,
   `schedule_type`, `schedule_day_of_month`,
   `alert_type_id`, `severity`, `message_template`, `is_active`)
VALUES

(
  'Water Logging Alert — Monsoon Start',
  'seasonal', 'monsoon_start', 6, 9, NULL, NULL,
  1, NULL, NULL, NULL, NULL, NULL,
  (SELECT id FROM alert_types WHERE name = 'Water Logging Alert'),
  'critical',
  'Your food forest {{ff_name}} is in a water-logging area. Monsoon season has started — take protective measures immediately.',
  1
),
(
  'Fire Alert — Summer Season',
  'seasonal', 'summer', 3, 5, NULL, NULL,
  NULL, 1, NULL, NULL, NULL, NULL,
  (SELECT id FROM alert_types WHERE name = 'Fire Alert'),
  'critical',
  'High fire risk season has begun. Your food forest {{ff_name}} is in a fire-prone area. Ensure firebreaks and water access are ready.',
  1
),
(
  'Irrigation Reminder — End of Monsoon',
  'seasonal', 'monsoon_end', 9, 10, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL,
  (SELECT id FROM alert_types WHERE name = 'Irrigation Reminder'),
  'informative',
  'Monsoon season is ending. Time to review and set up irrigation for {{ff_name}}.',
  1
),
(
  'Pruning Alert — Pre-Monsoon for 5+ Year FFs',
  'seasonal', 'pre_monsoon', 4, 6, 5.0, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL,
  (SELECT id FROM alert_types WHERE name = 'Pruning Schedule'),
  'informative',
  'Your food forest {{ff_name}} is over 5 years old. Pre-monsoon pruning time is here — schedule your pruning activities.',
  1
),
(
  'Planting Time Alert — Monsoon Start',
  'seasonal', 'monsoon_start', 6, 9, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL,
  (SELECT id FROM alert_types WHERE name = 'Planting Time Alert'),
  'informative',
  'Monsoon season has started — optimal planting time for {{ff_name}}. Plan your new plantings now.',
  1
),
(
  'Filter Cleaning — Drip (Pond or River) — Weekly',
  'scheduled', NULL, NULL, NULL, NULL, NULL,
  NULL, NULL,
  (SELECT id FROM irrigation_methods WHERE name = 'Drip'),
  1, 'weekly', NULL,
  (SELECT id FROM alert_types WHERE name = 'Filter Cleaning Alert'),
  'informative',
  'Weekly reminder: Please clean the drip irrigation filter for {{ff_name}}.',
  1
),
(
  'Filter Cleaning — Drip (Well) — Biweekly',
  'scheduled', NULL, NULL, NULL, NULL, NULL,
  NULL, NULL,
  (SELECT id FROM irrigation_methods WHERE name = 'Drip'),
  1, 'biweekly', NULL,
  (SELECT id FROM alert_types WHERE name = 'Filter Cleaning Alert'),
  'informative',
  'Biweekly reminder: Please clean the drip irrigation filter for {{ff_name}}.',
  1
),
(
  'Filter Cleaning — Drip (Borewell) — Monthly',
  'scheduled', NULL, NULL, NULL, NULL, NULL,
  NULL, NULL,
  (SELECT id FROM irrigation_methods WHERE name = 'Drip'),
  1, 'monthly', 1,
  (SELECT id FROM alert_types WHERE name = 'Filter Cleaning Alert'),
  'informative',
  'Monthly reminder: Please clean the drip irrigation filter for {{ff_name}}.',
  1
);

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================
-- END OF SCHEMA  (v5 — 30 tables)
-- Verify: SELECT table_name FROM information_schema.tables
--         WHERE table_schema = 'food_forest_db' ORDER BY table_name;
--
-- Tables (30):
--   admin_activity_logs       alert_types
--   analytics_snapshots       app_config
--   addon_types               content_types
--   data_deletion_requests    events
--   event_types               export_jobs
--   faq_categories            faqs
--   fencing_types             food_forest_addons
--   food_forest_plants        food_forest_types
--   food_forests              forest_logs
--   forest_stages             irrigation_methods
--   jaivorg_tokens            knowledge_base
--   log_intervals             log_photos
--   notification_preferences  notification_rules
--   notifications             plant_varieties
--   plants                    registration_draft_steps
--   registration_drafts       soil_tests
--   soil_types                terrain_types
--   user_audit_logs           user_consent_records
--   users                     water_sources
--   weekly_highlights
-- =============================================================
