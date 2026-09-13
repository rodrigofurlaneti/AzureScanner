-- ============================================================
-- DATABASE: AzureServerManager
-- Description: Cloud server management system with cost analysis
-- Database: MySQL 8.0+
-- ============================================================

-- Create database
CREATE DATABASE IF NOT EXISTS `azure_server_manager` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `azure_server_manager`;

-- ============================================================
-- TABLE 1: Static SKU and Pricing Data
-- ============================================================
CREATE TABLE `skus` (
    `sku_id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `type` VARCHAR(20) NOT NULL,  -- 'General', 'Memory', 'Compute'
    `vcpus` INT NOT NULL,
    `ram_gb` DECIMAL(10,2) NOT NULL,
    `storage_gb` INT NOT NULL,
    `regions` VARCHAR(255) NOT NULL,  -- 'brazilsouth,eastus,westus'
    `price_regular_hourly_usd` DECIMAL(10,4) NOT NULL,
    `price_spot_hourly_usd` DECIMAL(10,4) NOT NULL,
    `discount_spot_percentage` INT GENERATED ALWAYS AS
        (CAST((1 - `price_spot_hourly_usd` / `price_regular_hourly_usd`) * 100 AS UNSIGNED)) STORED,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `active` BOOLEAN DEFAULT TRUE,
    INDEX idx_sku_name (`name`),
    INDEX idx_sku_type (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 2: Created Virtual Machines
-- ============================================================
CREATE TABLE `virtual_machines` (
    `vm_id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `resource_group` VARCHAR(100) NOT NULL,
    `region` VARCHAR(50) NOT NULL,
    `sku_id` INT NOT NULL,
    `priority` VARCHAR(20) NOT NULL,  -- 'Regular' or 'Spot'
    `status` VARCHAR(20) NOT NULL,  -- 'Running', 'Stopped', 'Deallocated', 'Deleted'
    `public_ip` VARCHAR(15),
    `ssh_username` VARCHAR(100),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `active` BOOLEAN DEFAULT TRUE,
    `created_by_user_id` INT,
    FOREIGN KEY (`sku_id`) REFERENCES `skus`(`sku_id`),
    FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`user_id`),
    INDEX idx_vm_region (`region`),
    INDEX idx_vm_status (`status`),
    INDEX idx_vm_created_by (`created_by_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 3: Cost History
-- ============================================================
CREATE TABLE `cost_history` (
    `cost_id` INT AUTO_INCREMENT PRIMARY KEY,
    `vm_id` INT NOT NULL,
    `cost_date` DATE NOT NULL,
    `hours_running` DECIMAL(5,2) DEFAULT 24.0,
    `billing_type` VARCHAR(20) NOT NULL,  -- 'Regular' or 'Spot'
    `cost_usd` DECIMAL(10,4) NOT NULL,
    `savings_vs_regular_usd` DECIMAL(10,4),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`vm_id`) REFERENCES `virtual_machines`(`vm_id`),
    INDEX idx_cost_date (`cost_date`),
    INDEX idx_cost_vm (`vm_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 4: User Configuration
-- ============================================================
CREATE TABLE `configurations` (
    `config_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `preferred_regions` VARCHAR(255),  -- 'brazilsouth;eastus'
    `prefer_spot` BOOLEAN DEFAULT TRUE,
    `enable_cost_alerts` BOOLEAN DEFAULT TRUE,
    `monthly_cost_limit_usd` DECIMAL(10,2),
    `worker_execution_time` VARCHAR(10) DEFAULT '03:00',  -- Time for midnight worker
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`),
    INDEX idx_config_user (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 5: Daily Ranking (created by Worker)
-- ============================================================
CREATE TABLE `daily_rankings` (
    `ranking_id` INT AUTO_INCREMENT PRIMARY KEY,
    `ranking_date` DATE NOT NULL,
    `sku_id` INT NOT NULL,
    `region` VARCHAR(50) NOT NULL,
    `position` INT NOT NULL,  -- 1st cheapest, 2nd, etc
    `cost_regular_hourly_usd` DECIMAL(10,4),
    `cost_spot_hourly_usd` DECIMAL(10,4),
    `savings_usd` DECIMAL(10,4),
    `savings_percentage` INT,
    `recommendation` VARCHAR(255),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`sku_id`) REFERENCES `skus`(`sku_id`),
    INDEX idx_ranking_date (`ranking_date`),
    INDEX idx_ranking_sku (`sku_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 6: Operation Logs (Audit Trail)
-- ============================================================
CREATE TABLE `operation_logs` (
    `log_id` INT AUTO_INCREMENT PRIMARY KEY,
    `operation` VARCHAR(100) NOT NULL,  -- 'Create VM', 'Stop VM', 'Convert Spot'
    `vm_id` INT,
    `user_id` INT,
    `status` VARCHAR(20) NOT NULL,  -- 'Success', 'Error', 'Warning'
    `message` VARCHAR(500),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`vm_id`) REFERENCES `virtual_machines`(`vm_id`),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`),
    INDEX idx_log_date (`created_at`),
    INDEX idx_log_user (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- VIEW 1: Current Cost Summary
-- ============================================================
CREATE VIEW `v_current_cost_summary` AS
SELECT
    vm.`name`,
    s.`name` AS sku_name,
    vm.`priority`,
    vm.`status`,
    s.`price_regular_hourly_usd` * 24 AS daily_cost_regular_usd,
    s.`price_spot_hourly_usd` * 24 AS daily_cost_spot_usd,
    ROUND((s.`price_regular_hourly_usd` - s.`price_spot_hourly_usd`) * 24, 4) AS daily_savings_usd,
    ROUND((s.`price_regular_hourly_usd` - s.`price_spot_hourly_usd`) * 24 * 30, 2) AS monthly_savings_usd
FROM `virtual_machines` vm
INNER JOIN `skus` s ON vm.`sku_id` = s.`sku_id`
WHERE vm.`active` = TRUE;

-- ============================================================
-- VIEW 2: Cheapest SKUs Ranking
-- ============================================================
CREATE VIEW `v_cheapest_skus` AS
SELECT
    s.`name`,
    s.`vcpus`,
    s.`ram_gb`,
    s.`price_regular_hourly_usd` * 24 AS daily_cost_regular,
    s.`price_spot_hourly_usd` * 24 AS daily_cost_spot,
    s.`discount_spot_percentage`,
    ROW_NUMBER() OVER (ORDER BY s.`price_spot_hourly_usd`) AS position_cheapest
FROM `skus` s
WHERE s.`active` = TRUE;

-- ============================================================
-- Insert Static Data - SKU Pricing (Brazil & USA)
-- ============================================================
INSERT INTO `skus`
(`name`, `type`, `vcpus`, `ram_gb`, `storage_gb`, `regions`, `price_regular_hourly_usd`, `price_spot_hourly_usd`)
VALUES
-- General Purpose (Cheapest)
('Standard_B1s', 'General', 1, 1.0, 30, 'brazilsouth,eastus,westus', 0.0120, 0.0030),
('Standard_B1ms', 'General', 1, 2.0, 30, 'brazilsouth,eastus,westus', 0.0244, 0.0049),
('Standard_B2s', 'General', 2, 4.0, 30, 'brazilsouth,eastus,westus', 0.0488, 0.0098),
('Standard_D2as_v4', 'General', 2, 8.0, 75, 'brazilsouth,eastus,westus', 0.1203, 0.0180),
('Standard_D4as_v4', 'General', 4, 16.0, 150, 'brazilsouth,eastus,westus', 0.2406, 0.0361),
-- Memory Optimized
('Standard_E2s_v3', 'Memory', 2, 16.0, 32, 'brazilsouth,eastus,westus', 0.1606, 0.0481),
('Standard_E4s_v3', 'Memory', 4, 32.0, 64, 'brazilsouth,eastus,westus', 0.3211, 0.0963),
-- Compute Optimized
('Standard_F2s_v2', 'Compute', 2, 4.0, 32, 'brazilsouth,eastus,westus', 0.0871, 0.0262);

-- ============================================================
-- Display Results
-- ============================================================
SELECT '✅ Database created successfully!' AS status;
SELECT '✅ 6 tables created' AS info;
SELECT '✅ 2 views created' AS info;
SELECT '✅ 8 SKUs inserted' AS info;
SELECT COUNT(*) AS total_skus FROM `skus`;
