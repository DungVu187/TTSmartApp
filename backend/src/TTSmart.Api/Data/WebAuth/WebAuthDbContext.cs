using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Data.WebAuth;

public sealed class WebAuthDbContext(DbContextOptions<WebAuthDbContext> options) : DbContext(options)
{
    public DbSet<WebUser> Users => Set<WebUser>();
    public DbSet<WebRole> Roles => Set<WebRole>();
    public DbSet<WebUserRole> UserRoles => Set<WebUserRole>();
    public DbSet<WebFunction> Functions => Set<WebFunction>();
    public DbSet<WebFunctionRole> FunctionRoles => Set<WebFunctionRole>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var user = modelBuilder.Entity<WebUser>();
        user.ToTable("User", "dbo");
        user.HasKey(item => item.UserId).HasName("PK_User");
        user.Property(item => item.UserId).ValueGeneratedOnAdd();
        user.Property(item => item.FullName).HasColumnType("nvarchar(200)").HasMaxLength(200);
        user.Property(item => item.UserName).HasColumnType("nvarchar(100)").HasMaxLength(100).IsRequired();
        user.Property(item => item.Password).HasColumnType("varchar(50)").IsRequired();
        user.Property(item => item.Email).HasColumnType("varchar(50)");
        user.Property(item => item.Code).HasColumnType("nvarchar(100)").HasMaxLength(100);
        user.Property(item => item.Avata).HasColumnType("nvarchar(max)");
        user.Property(item => item.Address).HasMaxLength(200);
        user.Property(item => item.Phone).HasColumnType("varchar(50)");
        user.Property(item => item.KeyLock).HasColumnType("nvarchar(40)").HasMaxLength(40);
        user.Property(item => item.CreatedAt).HasColumnType("datetime");
        user.Property(item => item.UpdatedAt).HasColumnType("datetime");
        user.Property(item => item.TokenSince).HasColumnType("datetime");
        user.Property(item => item.RegEmail).HasColumnType("nvarchar(100)").HasMaxLength(100);
        user.Property(item => item.BranchId).HasColumnType("nvarchar(1000)").HasMaxLength(1000);

        var role = modelBuilder.Entity<WebRole>();
        role.ToTable("Role", "dbo");
        role.HasKey(item => item.RoleId).HasName("PK_Role");
        role.Property(item => item.RoleId).ValueGeneratedOnAdd();
        role.Property(item => item.Code).HasColumnType("nvarchar(100)").HasMaxLength(100).IsRequired();
        role.Property(item => item.Name).HasColumnType("nvarchar(1000)").HasMaxLength(1000).IsRequired();
        role.Property(item => item.Note).HasColumnType("nvarchar(max)");
        role.Property(item => item.CreatedAt).HasColumnType("datetime");
        role.Property(item => item.UpdatedAt).HasColumnType("datetime");

        var userRole = modelBuilder.Entity<WebUserRole>();
        userRole.ToTable("UserRole", "dbo");
        userRole.HasKey(item => item.UserRoleId).HasName("PK_UserRole");
        userRole.Property(item => item.UserRoleId).ValueGeneratedOnAdd();
        userRole.Property(item => item.UserId).IsRequired();
        userRole.Property(item => item.RoleId).IsRequired();
        userRole.Property(item => item.CreatedAt).HasColumnType("datetime");
        userRole.HasOne(item => item.User).WithMany(item => item.UserRoles)
            .HasForeignKey(item => item.UserId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_UserRole_User");
        role.Ignore(item => item.UserRoles);
        userRole.Ignore(item => item.Role);

        var function = modelBuilder.Entity<WebFunction>();
        function.ToTable("Function", "dbo");
        function.HasKey(item => item.FunctionId).HasName("PK_Function");
        function.Property(item => item.FunctionId).ValueGeneratedOnAdd();
        function.Property(item => item.Name).HasColumnType("nvarchar(200)").HasMaxLength(200).IsRequired();
        function.Property(item => item.Code).HasColumnType("nvarchar(100)").HasMaxLength(100).IsRequired();
        function.Property(item => item.FunctionParentId).IsRequired();
        function.Property(item => item.Url).HasColumnType("nvarchar(400)").HasMaxLength(400);
        function.Property(item => item.Note).HasColumnType("nvarchar(4000)").HasMaxLength(4000);
        function.Property(item => item.Icon).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        function.Property(item => item.CreatedAt).HasColumnType("datetime");
        function.Property(item => item.UpdatedAt).HasColumnType("datetime");

        var functionRole = modelBuilder.Entity<WebFunctionRole>();
        functionRole.ToTable("FunctionRole", "dbo");
        functionRole.HasKey(item => item.FunctionRoleId).HasName("PK_FunctionRole");
        functionRole.Property(item => item.FunctionRoleId).ValueGeneratedOnAdd();
        functionRole.Property(item => item.TargetId).IsRequired();
        functionRole.Property(item => item.FunctionId).IsRequired();
        functionRole.Property(item => item.ActiveKey).HasColumnType("nvarchar(40)").HasMaxLength(40);
        functionRole.Property(item => item.CreatedAt).HasColumnType("datetime");
        functionRole.Property(item => item.UpdatedAt).HasColumnType("datetime");
        functionRole.HasOne(item => item.Function).WithMany(item => item.FunctionRoles)
            .HasForeignKey(item => item.FunctionId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_FunctionRole_Function");

        base.OnModelCreating(modelBuilder);
    }
}
