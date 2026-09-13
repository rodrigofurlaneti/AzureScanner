// ============================================================
// Entity Framework Core Models - MySQL
// Azure Server Manager - All in English
// ============================================================

using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AzureServerManager.Core.Models
{
    // ============================================================
    // SKU Model
    // ============================================================
    [Table("skus")]
    public class SKU
    {
        [Key]
        [Column("sku_id")]
        public int SKUId { get; set; }

        [Column("name")]
        [Required]
        [StringLength(50)]
        public string Name { get; set; }

        [Column("type")]
        [StringLength(20)]
        public string Type { get; set; }  // 'General', 'Memory', 'Compute'

        [Column("vcpus")]
        public int VCPUs { get; set; }

        [Column("ram_gb")]
        public decimal RamGB { get; set; }

        [Column("storage_gb")]
        public int StorageGB { get; set; }

        [Column("regions")]
        public string Regions { get; set; }  // 'brazilsouth,eastus,westus'

        [Column("price_regular_hourly_usd")]
        public decimal PriceRegularHourlyUSD { get; set; }

        [Column("price_spot_hourly_usd")]
        public decimal PriceSpotHourlyUSD { get; set; }

        [Column("discount_spot_percentage")]
        public int DiscountSpotPercentage { get; set; }

        [Column("active")]
        public bool Active { get; set; } = true;

        [Column("updated_at")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public virtual ICollection<VirtualMachine> VirtualMachines { get; set; }
        public virtual ICollection<DailyRanking> DailyRankings { get; set; }
    }

    // ============================================================
    // User Model
    // ============================================================
    [Table("users")]
    public class User
    {
        [Key]
        [Column("user_id")]
        public int UserId { get; set; }

        [Column("username")]
        [Required]
        [StringLength(100)]
        public string Username { get; set; }

        [Column("email")]
        [Required]
        [StringLength(100)]
        public string Email { get; set; }

        [Column("password_hash")]
        [Required]
        [StringLength(255)]
        public string PasswordHash { get; set; }

        [Column("full_name")]
        [StringLength(150)]
        public string FullName { get; set; }

        [Column("active")]
        public bool Active { get; set; } = true;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [Column("last_login_at")]
        public DateTime? LastLoginAt { get; set; }

        [Column("failed_login_attempts")]
        public int FailedLoginAttempts { get; set; } = 0;

        [Column("locked")]
        public bool Locked { get; set; } = false;

        // Navigation properties
        public virtual ICollection<UserRole> UserRoles { get; set; }
        public virtual ICollection<VirtualMachine> CreatedVirtualMachines { get; set; }
        public virtual ICollection<LoginSession> LoginSessions { get; set; }
        public virtual ICollection<OperationLog> OperationLogs { get; set; }
        public virtual ICollection<AuditLog> AuditLogs { get; set; }
        public virtual Configuration Configuration { get; set; }
    }

    // ============================================================
    // Role Model
    // ============================================================
    [Table("roles")]
    public class Role
    {
        [Key]
        [Column("role_id")]
        public int RoleId { get; set; }

        [Column("name")]
        [Required]
        [StringLength(50)]
        public string Name { get; set; }

        [Column("description")]
        [StringLength(255)]
        public string Description { get; set; }

        [Column("permissions")]
        public string Permissions { get; set; }  // JSON string

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public virtual ICollection<UserRole> UserRoles { get; set; }
    }

    // ============================================================
    // UserRole Model (Junction Table)
    // ============================================================
    [Table("user_roles")]
    public class UserRole
    {
        [Key]
        [Column("user_role_id")]
        public int UserRoleId { get; set; }

        [Column("user_id")]
        public int UserId { get; set; }

        [Column("role_id")]
        public int RoleId { get; set; }

        [Column("assigned_at")]
        public DateTime AssignedAt { get; set; } = DateTime.UtcNow;

        // Foreign keys
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }

        [ForeignKey(nameof(RoleId))]
        public virtual Role Role { get; set; }
    }

    // ============================================================
    // Virtual Machine Model
    // ============================================================
    [Table("virtual_machines")]
    public class VirtualMachine
    {
        [Key]
        [Column("vm_id")]
        public int VMId { get; set; }

        [Column("name")]
        [Required]
        [StringLength(100)]
        public string Name { get; set; }

        [Column("resource_group")]
        [Required]
        [StringLength(100)]
        public string ResourceGroup { get; set; }

        [Column("region")]
        [Required]
        [StringLength(50)]
        public string Region { get; set; }

        [Column("sku_id")]
        public int SKUId { get; set; }

        [Column("priority")]
        [StringLength(20)]
        public string Priority { get; set; }  // 'Regular' or 'Spot'

        [Column("status")]
        [StringLength(20)]
        public string Status { get; set; }  // 'Running', 'Stopped', 'Deallocated', 'Deleted'

        [Column("public_ip")]
        [StringLength(15)]
        public string PublicIP { get; set; }

        [Column("ssh_username")]
        [StringLength(100)]
        public string SSHUsername { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [Column("updated_at")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        [Column("active")]
        public bool Active { get; set; } = true;

        [Column("created_by_user_id")]
        public int? CreatedByUserId { get; set; }

        // Foreign keys
        [ForeignKey(nameof(SKUId))]
        public virtual SKU SKU { get; set; }

        [ForeignKey(nameof(CreatedByUserId))]
        public virtual User CreatedByUser { get; set; }

        // Navigation properties
        public virtual ICollection<CostHistory> CostHistories { get; set; }
    }

    // ============================================================
    // Cost History Model
    // ============================================================
    [Table("cost_history")]
    public class CostHistory
    {
        [Key]
        [Column("cost_id")]
        public int CostId { get; set; }

        [Column("vm_id")]
        public int VMId { get; set; }

        [Column("cost_date")]
        public DateTime CostDate { get; set; }

        [Column("hours_running")]
        public decimal HoursRunning { get; set; } = 24.0m;

        [Column("billing_type")]
        [StringLength(20)]
        public string BillingType { get; set; }  // 'Regular' or 'Spot'

        [Column("cost_usd")]
        public decimal CostUSD { get; set; }

        [Column("savings_vs_regular_usd")]
        public decimal SavingsVsRegularUSD { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign key
        [ForeignKey(nameof(VMId))]
        public virtual VirtualMachine VirtualMachine { get; set; }
    }

    // ============================================================
    // Configuration Model
    // ============================================================
    [Table("configurations")]
    public class Configuration
    {
        [Key]
        [Column("config_id")]
        public int ConfigId { get; set; }

        [Column("user_id")]
        public int UserId { get; set; }

        [Column("preferred_regions")]
        public string PreferredRegions { get; set; }  // 'brazilsouth;eastus'

        [Column("prefer_spot")]
        public bool PreferSpot { get; set; } = true;

        [Column("enable_cost_alerts")]
        public bool EnableCostAlerts { get; set; } = true;

        [Column("monthly_cost_limit_usd")]
        public decimal? MonthlyCostLimitUSD { get; set; }

        [Column("worker_execution_time")]
        [StringLength(10)]
        public string WorkerExecutionTime { get; set; } = "03:00";

        [Column("updated_at")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Foreign key
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }
    }

    // ============================================================
    // Daily Ranking Model (created by Worker)
    // ============================================================
    [Table("daily_rankings")]
    public class DailyRanking
    {
        [Key]
        [Column("ranking_id")]
        public int RankingId { get; set; }

        [Column("ranking_date")]
        public DateTime RankingDate { get; set; }

        [Column("sku_id")]
        public int SKUId { get; set; }

        [Column("region")]
        [StringLength(50)]
        public string Region { get; set; }

        [Column("position")]
        public int Position { get; set; }  // 1st cheapest, 2nd, etc

        [Column("cost_regular_hourly_usd")]
        public decimal CostRegularHourlyUSD { get; set; }

        [Column("cost_spot_hourly_usd")]
        public decimal CostSpotHourlyUSD { get; set; }

        [Column("savings_usd")]
        public decimal SavingsUSD { get; set; }

        [Column("savings_percentage")]
        public int SavingsPercentage { get; set; }

        [Column("recommendation")]
        [StringLength(255)]
        public string Recommendation { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign key
        [ForeignKey(nameof(SKUId))]
        public virtual SKU SKU { get; set; }
    }

    // ============================================================
    // Operation Log Model
    // ============================================================
    [Table("operation_logs")]
    public class OperationLog
    {
        [Key]
        [Column("log_id")]
        public int LogId { get; set; }

        [Column("operation")]
        [Required]
        [StringLength(100)]
        public string Operation { get; set; }  // 'Create VM', 'Stop VM', etc

        [Column("vm_id")]
        public int? VMId { get; set; }

        [Column("user_id")]
        public int? UserId { get; set; }

        [Column("status")]
        [Required]
        [StringLength(20)]
        public string Status { get; set; }  // 'Success', 'Error', 'Warning'

        [Column("message")]
        [StringLength(500)]
        public string Message { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign keys
        [ForeignKey(nameof(VMId))]
        public virtual VirtualMachine VirtualMachine { get; set; }

        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }
    }

    // ============================================================
    // Audit Log Model
    // ============================================================
    [Table("audit_logs")]
    public class AuditLog
    {
        [Key]
        [Column("audit_id")]
        public int AuditId { get; set; }

        [Column("user_id")]
        public int? UserId { get; set; }

        [Column("action")]
        [StringLength(100)]
        public string Action { get; set; }

        [Column("table_name")]
        [StringLength(100)]
        public string TableName { get; set; }

        [Column("record_id")]
        public int? RecordId { get; set; }

        [Column("old_data")]
        public string OldData { get; set; }  // JSON

        [Column("new_data")]
        public string NewData { get; set; }  // JSON

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [Column("ip_address")]
        [StringLength(45)]
        public string IpAddress { get; set; }

        // Foreign key
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }
    }

    // ============================================================
    // Login Session Model
    // ============================================================
    [Table("login_sessions")]
    public class LoginSession
    {
        [Key]
        [Column("session_id")]
        public int SessionId { get; set; }

        [Column("user_id")]
        public int UserId { get; set; }

        [Column("token")]
        [Required]
        [StringLength(500)]
        public string Token { get; set; }

        [Column("login_at")]
        public DateTime LoginAt { get; set; } = DateTime.UtcNow;

        [Column("expires_at")]
        public DateTime? ExpiresAt { get; set; }

        [Column("ip_address")]
        [StringLength(45)]
        public string IpAddress { get; set; }

        [Column("active")]
        public bool Active { get; set; } = true;

        // Foreign key
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; }
    }
}
