-- ============================================================
-- AUTHENTICATION: Multi-User with Roles
-- Database: MySQL
-- ============================================================

USE `azure_server_manager`;

-- ============================================================
-- TABLE: System Users
-- ============================================================
CREATE TABLE `users` (
    `user_id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(100) NOT NULL UNIQUE,
    `email` VARCHAR(100) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `full_name` VARCHAR(150),
    `active` BOOLEAN DEFAULT TRUE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_login_at` DATETIME,
    `failed_login_attempts` INT DEFAULT 0,
    `locked` BOOLEAN DEFAULT FALSE,
    INDEX idx_username (`username`),
    INDEX idx_email (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: Roles (Admin, Manager, Viewer)
-- ============================================================
CREATE TABLE `roles` (
    `role_id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `description` VARCHAR(255),
    `permissions` JSON,  -- {"create_vm":true,"delete_vm":true,...}
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: User-Role Mapping
-- ============================================================
CREATE TABLE `user_roles` (
    `user_role_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `role_id` INT NOT NULL,
    `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE,
    FOREIGN KEY (`role_id`) REFERENCES `roles`(`role_id`) ON DELETE CASCADE,
    UNIQUE KEY unique_user_role (`user_id`, `role_id`),
    INDEX idx_user (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: Login Sessions
-- ============================================================
CREATE TABLE `login_sessions` (
    `session_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `token` VARCHAR(500) NOT NULL UNIQUE,
    `login_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME,
    `ip_address` VARCHAR(45),
    `active` BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE,
    INDEX idx_token (`token`),
    INDEX idx_user_session (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: Access Audit Trail
-- ============================================================
CREATE TABLE `audit_logs` (
    `audit_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT,
    `action` VARCHAR(100),
    `table_name` VARCHAR(100),
    `record_id` INT,
    `old_data` JSON,
    `new_data` JSON,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `ip_address` VARCHAR(45),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL,
    INDEX idx_audit_date (`created_at`),
    INDEX idx_audit_user (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Insert Default Roles
-- ============================================================
INSERT INTO `roles` (`name`, `description`, `permissions`) VALUES
(
    'Admin',
    'Full access to system',
    '{"create_vm":true,"delete_vm":true,"update_config":true,"view_reports":true,"manage_users":true}'
),
(
    'Manager',
    'Manage VMs and view reports',
    '{"create_vm":true,"delete_vm":true,"update_config":true,"view_reports":true,"manage_users":false}'
),
(
    'Viewer',
    'View VMs and reports only',
    '{"create_vm":false,"delete_vm":false,"update_config":false,"view_reports":true,"manage_users":false}'
);

-- ============================================================
-- Insert Default Admin User
-- Password: Admin@2026 (SHA256 hash)
-- ============================================================
INSERT INTO `users`
(`username`, `email`, `password_hash`, `full_name`, `active`)
VALUES
('admin', 'rodrigofurlaneti31@gmail.com', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'Rodrigo Furlaneti', TRUE);

-- ============================================================
-- Assign Admin Role to Admin User
-- ============================================================
INSERT INTO `user_roles` (`user_id`, `role_id`)
SELECT u.`user_id`, r.`role_id`
FROM `users` u, `roles` r
WHERE u.`username` = 'admin' AND r.`name` = 'Admin';

-- ============================================================
-- VIEW: Users with Their Roles
-- ============================================================
CREATE VIEW `v_users_with_roles` AS
SELECT
    u.`user_id`,
    u.`username`,
    u.`email`,
    u.`full_name`,
    u.`active`,
    u.`last_login_at`,
    GROUP_CONCAT(r.`name` SEPARATOR ', ') AS roles,
    u.`created_at`
FROM `users` u
LEFT JOIN `user_roles` ur ON u.`user_id` = ur.`user_id`
LEFT JOIN `roles` r ON ur.`role_id` = r.`role_id`
GROUP BY u.`user_id`, u.`username`, u.`email`, u.`full_name`, u.`active`, u.`last_login_at`, u.`created_at`;

-- ============================================================
-- VIEW: Active Sessions
-- ============================================================
CREATE VIEW `v_active_sessions` AS
SELECT
    ls.`session_id`,
    u.`username`,
    ls.`login_at`,
    ls.`expires_at`,
    ls.`ip_address`,
    TIMESTAMPDIFF(HOUR, ls.`login_at`, NOW()) AS hours_active
FROM `login_sessions` ls
INNER JOIN `users` u ON ls.`user_id` = u.`user_id`
WHERE ls.`active` = TRUE AND ls.`expires_at` > NOW();

-- ============================================================
-- Display Results
-- ============================================================
SELECT '✅ Authentication tables created!' AS status;
SELECT '✅ 3 roles created: Admin, Manager, Viewer' AS info;
SELECT '✅ Default admin user created' AS info;
SELECT '✅ 2 authentication views created' AS info;
