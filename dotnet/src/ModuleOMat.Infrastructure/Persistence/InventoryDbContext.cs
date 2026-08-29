using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace ModuleOMat.Infrastructure.Persistence;

public sealed class InventoryDbContext(DbContextOptions<InventoryDbContext> options) : DbContext(options)
{
    public DbSet<EurorackModuleEntity> EurorackModules => Set<EurorackModuleEntity>();
    public DbSet<ModuleTypeEntity> ModuleTypes => Set<ModuleTypeEntity>();
    public DbSet<YoutubeVideoEntity> YoutubeVideos => Set<YoutubeVideoEntity>();
    public DbSet<PriceObservationEntity> PriceObservations => Set<PriceObservationEntity>();
    public DbSet<BackupRunEntity> BackupRuns => Set<BackupRunEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var jsonOptions = new JsonSerializerOptions();
        var subtypesConverter = new ValueConverter<List<string>, string>(
            list => JsonSerializer.Serialize(list, jsonOptions),
            json => JsonSerializer.Deserialize<List<string>>(json, jsonOptions) ?? new List<string>());

        modelBuilder.Entity<EurorackModuleEntity>(entity =>
        {
            entity.ToTable("eurorack_modules");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Manufacturer).HasColumnName("manufacturer").IsRequired();
            entity.Property(e => e.Name).HasColumnName("name").IsRequired();
            entity.Property(e => e.Hp).HasColumnName("hp").IsRequired();
            entity.Property(e => e.Type).HasColumnName("type").IsRequired();
            entity.Property(e => e.Subtypes)
                .HasColumnName("subtypes")
                .HasConversion(subtypesConverter)
                .HasColumnType("TEXT");
            entity.Property(e => e.CurrentDrawPlus12VMa).HasColumnName("current_draw_plus12v_ma");
            entity.Property(e => e.CurrentDrawMinus12VMa).HasColumnName("current_draw_minus12v_ma");
            entity.Property(e => e.CurrentDrawPlus5VMa).HasColumnName("current_draw_plus5v_ma");
            entity.Property(e => e.DepthMm).HasColumnName("depth_mm");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.ManualUrl).HasColumnName("manual_url");
            entity.Property(e => e.PurchasePrice).HasColumnName("purchase_price").HasColumnType("TEXT");
            entity.Property(e => e.CurrentValue).HasColumnName("current_value").HasColumnType("TEXT");
            entity.Property(e => e.ManualPdfKey).HasColumnName("manual_pdf_key");
            entity.Property(e => e.ManualPdfFilename).HasColumnName("manual_pdf_filename");
            entity.Property(e => e.ManualPdfContentType).HasColumnName("manual_pdf_content_type");
            entity.Property(e => e.ManualPdfSizeBytes).HasColumnName("manual_pdf_size_bytes");
            entity.Property(e => e.DeletedAt).HasColumnName("deleted_at");
            entity.Property(e => e.InsertedAt).HasColumnName("inserted_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
            entity.HasIndex(e => e.Manufacturer);
            entity.HasIndex(e => e.Type);
            entity.HasIndex(e => e.DeletedAt);
            entity.HasMany(e => e.YoutubeVideos)
                .WithOne(v => v.Module)
                .HasForeignKey(v => v.EurorackModuleId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(e => e.PriceObservations)
                .WithOne(o => o.Module)
                .HasForeignKey(o => o.EurorackModuleId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasQueryFilter(e => e.DeletedAt == null);
        });

        modelBuilder.Entity<ModuleTypeEntity>(entity =>
        {
            entity.ToTable("module_types");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired();
            entity.Property(e => e.InsertedAt).HasColumnName("inserted_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
            entity.HasIndex(e => e.Name).IsUnique();
        });

        modelBuilder.Entity<YoutubeVideoEntity>(entity =>
        {
            entity.ToTable("youtube_videos");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Url).HasColumnName("url").IsRequired();
            entity.Property(e => e.Position).HasColumnName("position").IsRequired();
            entity.Property(e => e.EurorackModuleId).HasColumnName("eurorack_module_id").IsRequired();
            entity.Property(e => e.InsertedAt).HasColumnName("inserted_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
            entity.HasIndex(e => e.EurorackModuleId);
            entity.HasIndex(e => new { e.EurorackModuleId, e.Position });
        });

        modelBuilder.Entity<PriceObservationEntity>(entity =>
        {
            entity.ToTable("module_price_observations");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Amount).HasColumnName("amount").HasColumnType("TEXT").IsRequired();
            entity.Property(e => e.Currency).HasColumnName("currency").IsRequired();
            entity.Property(e => e.Source).HasColumnName("source").IsRequired();
            entity.Property(e => e.SourceUrl).HasColumnName("source_url");
            entity.Property(e => e.ObservedOn).HasColumnName("observed_on").IsRequired();
            entity.Property(e => e.Notes).HasColumnName("notes");
            entity.Property(e => e.EurorackModuleId).HasColumnName("eurorack_module_id").IsRequired();
            entity.Property(e => e.InsertedAt).HasColumnName("inserted_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
        });

        modelBuilder.Entity<BackupRunEntity>(entity =>
        {
            entity.ToTable("backup_runs");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Filename).HasColumnName("filename");
            entity.Property(e => e.SizeBytes).HasColumnName("size_bytes");
            entity.Property(e => e.Success).HasColumnName("success").IsRequired();
            entity.Property(e => e.InsertedAt).HasColumnName("inserted_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
            entity.HasIndex(e => e.InsertedAt);
            entity.HasIndex(e => new { e.Success, e.InsertedAt });
        });
    }
}

public sealed class EurorackModuleEntity
{
    public int Id { get; set; }
    public string Manufacturer { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int Hp { get; set; }
    public string Type { get; set; } = string.Empty;
    public List<string> Subtypes { get; set; } = [];
    public int? CurrentDrawPlus12VMa { get; set; }
    public int? CurrentDrawMinus12VMa { get; set; }
    public int? CurrentDrawPlus5VMa { get; set; }
    public int? DepthMm { get; set; }
    public string? Description { get; set; }
    public string? ManualUrl { get; set; }
    public decimal? PurchasePrice { get; set; }
    public decimal? CurrentValue { get; set; }
    public string? ManualPdfKey { get; set; }
    public string? ManualPdfFilename { get; set; }
    public string? ManualPdfContentType { get; set; }
    public int? ManualPdfSizeBytes { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime InsertedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<YoutubeVideoEntity> YoutubeVideos { get; set; } = [];
    public List<PriceObservationEntity> PriceObservations { get; set; } = [];
}

public sealed class ModuleTypeEntity
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime InsertedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class YoutubeVideoEntity
{
    public int Id { get; set; }
    public string Url { get; set; } = string.Empty;
    public int Position { get; set; }
    public int EurorackModuleId { get; set; }
    public DateTime InsertedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public EurorackModuleEntity? Module { get; set; }
}

public sealed class PriceObservationEntity
{
    public int Id { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public string Source { get; set; } = string.Empty;
    public string? SourceUrl { get; set; }
    public DateOnly ObservedOn { get; set; }
    public string? Notes { get; set; }
    public int EurorackModuleId { get; set; }
    public DateTime InsertedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public EurorackModuleEntity? Module { get; set; }
}

public sealed class BackupRunEntity
{
    public int Id { get; set; }
    public string? Filename { get; set; }
    public long? SizeBytes { get; set; }
    public bool Success { get; set; }
    public DateTime InsertedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
