using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Data.Notifications;

public sealed class NotificationDbContext(DbContextOptions<NotificationDbContext> options) : DbContext(options)
{
    public DbSet<NotificationEvent> NotificationEvents => Set<NotificationEvent>();
    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();
    public DbSet<NotificationSourceState> NotificationSourceStates => Set<NotificationSourceState>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var notificationEvent = modelBuilder.Entity<NotificationEvent>();
        notificationEvent.ToTable("NotificationEvents", "dbo");
        notificationEvent.HasKey(item => item.Id);
        notificationEvent.Property(item => item.Id).ValueGeneratedOnAdd();
        notificationEvent.Property(item => item.EventType).HasMaxLength(100).IsRequired();
        notificationEvent.Property(item => item.EntityType).HasMaxLength(100).IsRequired();
        notificationEvent.Property(item => item.EntityId).HasMaxLength(200).IsRequired();
        notificationEvent.Property(item => item.Title).HasMaxLength(500).IsRequired();
        notificationEvent.Property(item => item.Body).HasMaxLength(2000).IsRequired();
        notificationEvent.Property(item => item.DeduplicationKey).HasMaxLength(500).IsRequired();
        notificationEvent.Property(item => item.OccurredAtUtc).HasColumnType("datetime2(3)");
        notificationEvent.Property(item => item.CreatedAtUtc).HasColumnType("datetime2(3)");
        notificationEvent.HasIndex(item => item.DeduplicationKey).IsUnique();

        var userNotification = modelBuilder.Entity<UserNotification>();
        userNotification.ToTable("UserNotifications", "dbo");
        userNotification.HasKey(item => item.Id);
        userNotification.Property(item => item.Id).ValueGeneratedOnAdd();
        userNotification.Property(item => item.ReadAtUtc).HasColumnType("datetime2(3)");
        userNotification.Property(item => item.CreatedAtUtc).HasColumnType("datetime2(3)");
        userNotification.HasIndex(item => new { item.EventId, item.UserId }).IsUnique();
        userNotification.HasIndex(item => new { item.UserId, item.ReadAtUtc, item.Id });
        userNotification.HasOne(item => item.Event).WithMany(item => item.UserNotifications)
            .HasForeignKey(item => item.EventId).OnDelete(DeleteBehavior.Cascade);

        var sourceState = modelBuilder.Entity<NotificationSourceState>();
        sourceState.ToTable("NotificationSourceStates", "dbo");
        sourceState.HasKey(item => item.Id);
        sourceState.Property(item => item.Id).ValueGeneratedOnAdd();
        sourceState.Property(item => item.DetectorType).HasMaxLength(100).IsRequired();
        sourceState.Property(item => item.SourceKey).HasMaxLength(200).IsRequired();
        sourceState.Property(item => item.SourceVersion).HasMaxLength(500);
        sourceState.Property(item => item.Fingerprint).HasMaxLength(500);
        sourceState.Property(item => item.LastObservedAtUtc).HasColumnType("datetime2(3)");
        sourceState.Property(item => item.UpdatedAtUtc).HasColumnType("datetime2(3)");
        sourceState.HasIndex(item => new { item.DetectorType, item.StationId, item.SourceKey }).IsUnique();
    }
}
