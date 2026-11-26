options(warn = -1)
# Lampiran 1 — Impor dan Validasi Data
ALPHA <- 0.10
K_UTAMA <- 5L
K_EVALUASI <- 1:10
METHOD_ML <- "eigen"
options(scipen = 999, width = 240, max.print = 100000)
# Direktori data penelitian
ROOT_DIR <- "C:/Users/AJENG/OneDrive/Dokumen/BISMILLAH SKRIPSI/KODINGAN"
if (!dir.exists(ROOT_DIR)) stop("Folder KODINGAN tidak ditemukan: ", ROOT_DIR)
setwd(ROOT_DIR)
DATA_FILE <- file.path(ROOT_DIR, "DATA.xlsx")
SHP_FILE <- file.path(ROOT_DIR, "shapefile", "Kalimantan.shp")
if (!file.exists(DATA_FILE)) stop("DATA.xlsx tidak ditemukan: ", DATA_FILE)
if (!file.exists(SHP_FILE)) {
  stop("Shapefile tidak ditemukan: ", SHP_FILE,
       "\nPastikan folder shapefile berisi Kalimantan.shp, .shx, .dbf, dan .prj")
}

# Direktori keluaran gambar
OUT_MAP <- file.path(ROOT_DIR, "HASIL_GAMBAR_BAB4")
dir.create(OUT_MAP, recursive = TRUE, showWarnings = FALSE)
paket <- c("readxl", "dplyr", "sf", "ggplot2", "spdep", "spatialreg",
           "ggspatial")
belum <- paket[!vapply(paket, requireNamespace, logical(1), quietly = TRUE)]
if (length(belum) > 0) {
  stop("Paket R belum terpasang: ", paste(belum, collapse = ", "), "\nJalankan install.packages(c(",
       paste(sprintf('"%s"', belum), collapse = ", "), ")) lalu run ulang.")
}

tampil <- function(x, label) {
  cat("\n--- ", gsub("_", " ", sub("\\.csv$", "", label)), " ---\n", sep = "")
  print(x, row.names = FALSE, digits = 8)
  invisible(x)
}
judul <- function(teks) cat("\n", paste(rep("=", 72), collapse = ""),
                            "\n", teks, "\n", paste(rep("=",72),collapse=""), "\n")

# Pengaturan tampilan hasil
CETAK_DATA_LENGKAP <- FALSE
CETAK_MATRIKS_PENUH <- TRUE
CETAK_RINCIAN_TEKNIS <- FALSE

BUAT_QQ_OLS <- TRUE

format_angka <- function(x, digit = 4L) {
  skala <- 10^digit
  x_num <- as.numeric(x)
  x_bulat <- sign(x_num) * floor(abs(x_num) * skala + 0.5 + 1e-8) / skala
  v <- formatC(x_bulat, format = "f", digits = digit,
               big.mark = ".", decimal.mark = ",")
  v[is.na(x_num)] <- "–"
  sub("^-", "−", v)
}
cetak_tabel <- function(x, nomor, judul_tabel) {
  cat(sprintf("\n--- TABEL %s: %s ---\n", nomor, judul_tabel))
  print(x, row.names = FALSE, right = FALSE, quote = FALSE)
  invisible(x)
}
nama_parameter <- c(
  "(Intercept)" = "Konstanta",
  "kemiskinan" = "Kemiskinan",
  "tpt" = "TPT",
  "pengeluaran_perkapita" = "Pengeluaran per kapita",
  "kepadatan_penduduk" = "Kepadatan penduduk",
  "air_minum" = "Akses air minum layak",
  "rls" = "Rata-rata lama sekolah",
  "uhh" = "Umur harapan hidup"
)
keputusan_h0 <- function(p) ifelse(p < ALPHA, "Tolak H0", "Gagal Tolak H0")
signifikansi <- function(p) ifelse(p < ALPHA, "Signifikan", "Tidak signifikan")

# 1. VALIDASI DATA
judul("1. IMPOR DAN VALIDASI DATA")
data <- readxl::read_excel(DATA_FILE)
cat("Kolom Excel asli (harus konsisten urutannya):\n")
print(names(data))
if (ncol(data) != 10L) stop("DATA.xlsx wajib memiliki tepat 10 kolom.")
# Pemilihan nama berikut mengikuti POSISI kolom pada DATA.xlsx asli.
colnames(data) <- c("kab_kota", "provinsi", "sanitasi", "kemiskinan",
                    "air_minum", "kepadatan_penduduk", "rls", "tpt",
                    "pengeluaran_perkapita", "uhh")
data_raw <- as.data.frame(data)
normal_nama <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("[[:space:]]+", " ", x)
  x <- gsub("\\.", "", x)
  x
}
data_raw$KABUPATEN <- normal_nama(data_raw$kab_kota)
kol_num <- c("sanitasi", "kemiskinan", "air_minum", "kepadatan_penduduk",
             "rls", "tpt", "pengeluaran_perkapita", "uhh")
for (v in kol_num) {
  asal <- data_raw[[v]]
  # Konversi kolom numerik
  data_raw[[v]] <- suppressWarnings(as.numeric(trimws(as.character(asal))))
  if (any(!is.finite(data_raw[[v]]))) {
    stop("Nilai tidak numerik/NA pada kolom: ", v, "; baris Excel: ",
         paste(which(!is.finite(data_raw[[v]])) + 1, collapse = ", "))
  }
}
if (nrow(data_raw) != 56L) stop("Jumlah baris Excel bukan 56: ", nrow(data_raw))
if (anyDuplicated(data_raw$KABUPATEN)) stop("Nama wilayah duplikat di Excel.")
if (any(data_raw$sanitasi < 0 | data_raw$sanitasi > 100)) stop("Sanitasi di luar rentang 0-100")
if (any(data_raw$air_minum < 0 | data_raw$air_minum > 100)) stop("Air minum di luar rentang 0-100")
if (any(data_raw$pengeluaran_perkapita <= 0)) stop("Pengeluaran tidak positif")

# Konversi pengeluaran ke ribu rupiah.
# Misalnya 1.292.748 rupiah menjadi 1.292,748 ribu rupiah.
data_raw$pengeluaran_perkapita <- data_raw$pengeluaran_perkapita / 1000
shp <- sf::st_read(SHP_FILE, quiet = TRUE)
if (!("NAMOBJ" %in% names(shp))) stop("Shapefile tidak memiliki kolom NAMOBJ")
shp <- sf::st_zm(shp, drop = TRUE, what = "ZM")
if (is.na(sf::st_crs(shp))) stop("CRS shapefile tidak didefinisikan (.prj diperlukan)")
shp$KABUPATEN <- normal_nama(shp$NAMOBJ)
if (anyDuplicated(shp$KABUPATEN)) stop("Nama wilayah duplikat di SHP")
if (nrow(shp) != 56L) stop("Jumlah polygon SHP bukan 56: ", nrow(shp))
xls_saja <- setdiff(data_raw$KABUPATEN, shp$KABUPATEN)
shp_saja <- setdiff(shp$KABUPATEN, data_raw$KABUPATEN)
if (length(xls_saja) || length(shp_saja)) {
  tampil(data.frame(wilayah = c(xls_saja, shp_saja),
                    sumber = c(rep("Excel saja", length(xls_saja)), rep("SHP saja",length(shp_saja)))),
         "Nama wilayah Excel dan shapefile yang tidak cocok")
  stop("Nama wilayah tidak cocok; lihat daftar wilayah yang tercetak di Console.")
}

shp <- shp[order(shp$KABUPATEN), ]
idx <- match(shp$KABUPATEN, data_raw$KABUPATEN)
atribut <- data_raw[idx, setdiff(names(data_raw), c("KABUPATEN", "kab_kota")), drop = FALSE]
data_spasial <- sf::st_sf(atribut, KABUPATEN = shp$KABUPATEN, geometry = sf::st_geometry(shp))
data_spasial <- data_spasial[, c("KABUPATEN", "provinsi", kol_num)]
stopifnot(nrow(data_spasial) == 56L, !anyNA(sf::st_drop_geometry(data_spasial)))
if (any(!sf::st_is_valid(data_spasial))) {
  warning("Terdapat poligon tidak valid; diperbaiki dengan st_make_valid().")
  sf::st_geometry(data_spasial) <- sf::st_geometry(sf::st_make_valid(data_spasial))
}
cat("Berhasil mencocokkan 56 wilayah secara tepat.\n")

CRS_AEQD <- "+proj=aeqd +lat_0=0 +lon_0=114 +datum=WGS84 +units=m +no_defs"
proj <- sf::st_transform(data_spasial, crs = CRS_AEQD)
centroid <- sf::st_centroid(sf::st_geometry(proj))
coords <- sf::st_coordinates(centroid)
if (nrow(coords) != 56L) stop("Koordinat centroid bukan 56 titik")
data_spasial$centroid_x_m <- coords[, 1]
data_spasial$centroid_y_m <- coords[, 2]
data_df <- sf::st_drop_geometry(data_spasial)
y <- data_df$sanitasi

# Lampiran 2 — Eksplorasi Data 
# BAB 4.1 - EKSPLORASI DATA
# 4.1.1 Gambar 4.1 — Peta Wilayah Penelitian 

judul("BAB 4.1.1 - GAMBAR 4.1: PETA WILAYAH PENELITIAN")
peta_41 <- sf::st_transform(data_spasial, 4326)
# nama provinsi diseragamkan
prov_asli <- normal_nama(peta_41$provinsi)
prov_asli <- sub("^PROVINSI ", "", prov_asli)
nama_prov <- c( "KALIMANTAN TIMUR"   = "Kalimantan Timur", "KALIMANTAN SELATAN" = "Kalimantan Selatan",
                "KALIMANTAN BARAT"   = "Kalimantan Barat", "KALIMANTAN TENGAH"  = "Kalimantan Tengah",
                "KALIMANTAN UTARA"   = "Kalimantan Utara", "KALTIM"  = "Kalimantan Timur",
                "KALSEL"  = "Kalimantan Selatan", "KALBAR"  = "Kalimantan Barat", "KALTENG" = "Kalimantan Tengah",
                "KALTARA" = "Kalimantan Utara" )
peta_41$Provinsi <- unname(nama_prov[prov_asli])
if (anyNA(peta_41$Provinsi)) {
  stop("Nama provinsi tidak dikenali: ", paste(unique(prov_asli[ is.na(peta_41$Provinsi)
  ]), collapse = ", "))
}
stopifnot(nrow(peta_41) == 56)
warna_prov <- c( "Kalimantan Timur"   = "#176A46", "Kalimantan Selatan" = "#F2CC42",
                 "Kalimantan Barat"   = "#3478B9", "Kalimantan Tengah"  = "#951F36", "Kalimantan Utara"   = "#936447" )
peta_41$Provinsi <- factor( peta_41$Provinsi, levels = names(warna_prov) )
batas_prov <- peta_41 |>
  dplyr::select(Provinsi) |>
  dplyr::group_by(Provinsi) |>
  dplyr::summarise(.groups = "drop")
label_prov <- sf::st_transform( sf::st_point_on_surface( sf::st_transform(batas_prov, CRS_AEQD) ), 4326 )
p_41 <- ggplot2::ggplot() +
  # Warna provinsi dan batas kabupaten/kota
  ggplot2::geom_sf( data = peta_41, ggplot2::aes(fill = Provinsi), color = "#555555", linewidth = 0.18 ) +
  # Batas provinsi dibuat lebih tebal
  ggplot2::geom_sf( data = batas_prov, fill = NA, color = "#202020", linewidth = 0.85 ) +
  # Nama provinsi pada peta
  ggplot2::geom_sf_label( data = label_prov, ggplot2::aes(label = Provinsi), size = 2.8, fontface = "bold",
                          color = "#202020", fill = "white", alpha = 0.90, label.padding = grid::unit(0.13, "lines"),
                          show.legend = FALSE ) +
  # Legenda warna
  ggplot2::scale_fill_manual( values = warna_prov, drop = FALSE, name = "Provinsi" ) +
  ggplot2::coord_sf(datum = NA) +
  ggplot2::labs( title = "Peta Wilayah Penelitian", subtitle = "56 Kabupaten/Kota di Pulau Kalimantan",
                 caption = paste( "Warna menunjukkan provinsi,", "bukan persentase akses sanitasi layak." ) ) +
  ggplot2::theme_void(base_size = 12) +
  ggplot2::theme( plot.background = ggplot2::element_rect( fill = "white", color = NA ),
                  panel.background = ggplot2::element_rect( fill = "white", color = NA ),
                  plot.title = ggplot2::element_text( hjust = 0.5, face = "bold", size = 16 ),
                  plot.subtitle = ggplot2::element_text( hjust = 0.5, size = 11 ), plot.caption = ggplot2::element_text(
                    size = 8, color = "#555555" ), legend.position = "right", legend.title = ggplot2::element_text(
                      face = "bold", size = 11 ), legend.text = ggplot2::element_text( size = 10 ),
                  plot.margin = ggplot2::margin( 12, 12, 12, 12 ) )
if (requireNamespace("ggspatial", quietly = TRUE)) {
  p_41 <- p_41 + ggspatial::annotation_scale( location = "bl", width_hint = 0.18 ) +
    ggspatial::annotation_north_arrow( location = "tl", which_north = "true",
                                       style = ggspatial::north_arrow_fancy_orienteering )
}
print(p_41)
ggplot2::ggsave( filename = file.path( OUT_MAP, "Gambar_4_1_Peta_Provinsi_Kalimantan.png" ), plot = p_41,
                 width = 11, height = 7.5, dpi = 350, bg = "white" )
cat("Gambar 4.1 berhasil disimpan di:", OUT_MAP, "\n")

# 4.1.2 Statistik deskriptif, scatterplot dan korelasi
judul("BAB 4.1.2 - STATISTIK DESKRIPTIF DAN HUBUNGAN ANTARVARIABEL")
stat <- do.call(rbind, lapply(kol_num, function(v) {
  x <- data_df[[v]]
  data.frame(Variabel = v, N = length(x), Minimum = min(x),
             Rata_rata = sum(x) / length(x), Median = median(x),
             SD = sqrt(sum((x - mean(x))^2) / (length(x) - 1)), Maksimum = max(x))
}))
urutan_41 <- c("sanitasi", "kemiskinan", "tpt", "pengeluaran_perkapita",
               "kepadatan_penduduk", "air_minum", "rls", "uhh")
stat_41 <- stat[match(urutan_41, stat$Variabel), , drop = FALSE]
stopifnot(!anyNA(stat_41$Variabel))
nama_41 <- c(
  "Akses sanitasi layak (%)", "Penduduk miskin (%)",
  "Tingkat pengangguran terbuka (%)", "Pengeluaran per kapita (ribu rupiah)",
  "Kepadatan penduduk (jiwa/km²)", "Akses air minum layak (%)",
  "Rata-rata lama sekolah (tahun)", "Umur harapan hidup (tahun)")
tabel_41 <- data.frame(
  "Variabel" = nama_41,
  "Minimum" = format_angka(stat_41$Minimum, 2),
  "Rata-rata" = format_angka(stat_41$Rata_rata, 2),
  "Median" = format_angka(stat_41$Median, 2),
  "Simpangan baku" = format_angka(stat_41$SD, 2),
  "Maksimum" = format_angka(stat_41$Maksimum, 2),
  check.names = FALSE)
cetak_tabel(tabel_41, "4.1", "Statistik Deskriptif Variabel Penelitian Tahun 2025")
if (CETAK_DATA_LENGKAP) {
  tampil(data_df[, c("KABUPATEN", "provinsi", kol_num), drop = FALSE],
         "DATA PENELITIAN 56 WILAYAH")
}

# Korelasi Pearson
pearson <- function(x, y) {
  xc <- x - mean(x)
  yc <- y - mean(y)
  sum(xc * yc) / sqrt(sum(xc^2) * sum(yc^2))
}

# Grafik hubungan sanitasi dan tujuh variabel prediktor 
nama_x <- c( kemiskinan = "X1 - Penduduk miskin (%)", tpt = "X2 - TPT (%)",
             pengeluaran_perkapita = "X3 - Pengeluaran per kapita (ribu Rp)",
             kepadatan_penduduk = "X4 - Kepadatan penduduk (jiwa/km2)", air_minum = "X5 - Akses air minum layak (%)",
             rls = "X6 - Rata-rata lama sekolah (tahun)", uhh = "X7 - Umur harapan hidup (tahun)" )
scatter_data <- do.call( rbind, lapply(names(nama_x), function(v) {
  data.frame( Wilayah = data_df$KABUPATEN, Variabel = unname(nama_x[v]), X = as.numeric(data_df[[v]]),
              Y = as.numeric(data_df$sanitasi) )
}) )
scatter_data$Variabel <- factor( scatter_data$Variabel, levels = unname(nama_x) )
korelasi_yx <- do.call( rbind, lapply(names(nama_x), function(v) {
  data.frame( Variabel = unname(nama_x[v]), Korelasi = pearson(data_df[[v]], data_df$sanitasi) )
}) )
korelasi_yx$Variabel <- factor( korelasi_yx$Variabel, levels = unname(nama_x) )
korelasi_yx$Label <- sprintf( "r = %.2f", korelasi_yx$Korelasi )
p_scatter_yx <- ggplot2::ggplot( scatter_data, ggplot2::aes(x = X, y = Y) ) +
  ggplot2::geom_point( color = "#286A91", size = 2.2, alpha = 0.75 ) +
  ggplot2::geom_smooth( method = "lm", formula = y ~ x, se = FALSE, color = "#B34D3E", linewidth = 0.85 ) +
  ggplot2::geom_text( data = korelasi_yx, ggplot2::aes( x = -Inf, y = Inf, label = Label ),
                      inherit.aes = FALSE, hjust = -0.15, vjust = 1.4, size = 3.8, fontface = "bold", color = "#243746" ) +
  ggplot2::facet_wrap( ~Variabel, ncol = 2, scales = "free_x" ) +
  ggplot2::coord_cartesian( ylim = c(60, 100) ) +
  ggplot2::labs( title = "Hubungan Akses Sanitasi Layak dengan Variabel Prediktor",
                 subtitle = "Data 56 kabupaten/kota di Pulau Kalimantan tahun 2025", x = "Nilai variabel prediktor",
                 y = "Akses sanitasi layak (%)", caption = paste( "Titik = kabupaten/kota |",
                                                                  "Garis = kecenderungan linear |", "r = korelasi Pearson" ) ) +
  ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme( plot.background = ggplot2::element_rect( fill = "white", color = NA ),
                  panel.background = ggplot2::element_rect( fill = "white", color = NA ),
                  panel.grid.minor = ggplot2::element_blank(),
                  panel.grid.major = ggplot2::element_line( color = "#E5E5E5", linewidth = 0.25 ),
                  strip.background = ggplot2::element_rect( fill = "#EDF1F4", color = NA ),
                  strip.text = ggplot2::element_text( face = "bold", size = 10.5, color = "#243746" ),
                  plot.title = ggplot2::element_text( face = "bold", size = 15, hjust = 0.5 ),
                  plot.subtitle = ggplot2::element_text( size = 10.5, hjust = 0.5 ),
                  plot.caption = ggplot2::element_text( size = 9, color = "#555555" ),
                  axis.text = ggplot2::element_text( size = 9 ),
                  panel.spacing = grid::unit( 1.1, "lines" ),
                  plot.margin = ggplot2::margin( 12, 12, 12, 12 ) )
print(p_scatter_yx)
ggplot2::ggsave( filename = file.path( OUT_MAP, "34_Scatterplot_Hubungan_Y_dan_7X.png" ),
                 plot = p_scatter_yx, width = 10, height = 12, dpi = 350, bg = "white" )
if (CETAK_RINCIAN_TEKNIS) tampil(korelasi_yx, "Korelasi Sanitasi dan 7 Prediktor")

# Heatmap korelasi Pearson delapan variabel (Gambar 4.3)
label_pendek <- c( sanitasi = "Sanitasi", kemiskinan = "Kemiskinan", tpt = "TPT",
                   pengeluaran_perkapita = "Pengeluaran", kepadatan_penduduk = "Kepadatan", air_minum = "Air minum",
                   rls = "RLS", uhh = "UHH" )
variabel_viz <- names(label_pendek)
stopifnot(all(variabel_viz %in% names(data_df)))
korelasi <- outer(variabel_viz, variabel_viz, Vectorize(function(a, b) {
  pearson(data_df[[a]], data_df[[b]])
}))
dimnames(korelasi) <- list(variabel_viz, variabel_viz)

if (CETAK_RINCIAN_TEKNIS) {
  tampil(data.frame(Variabel = rownames(korelasi), korelasi, check.names = FALSE),
         "Matriks Korelasi Pearson")
}
heat_data <- as.data.frame( as.table(korelasi), stringsAsFactors = FALSE )
names(heat_data) <- c( "Variabel_Y", "Variabel_X", "r" )
heat_data$X <- factor( unname( label_pendek[ as.character(heat_data$Variabel_X) ] ),
                       levels = unname(label_pendek) )
heat_data$Y <- factor( unname( label_pendek[ as.character(heat_data$Variabel_Y) ] ),
                       levels = rev(unname(label_pendek)) )
heat_data$Teks <- sprintf( "%.2f", heat_data$r )
heat_data$Kontras <- ifelse( abs(heat_data$r) >= 0.62, "terang", "gelap" )
p_korelasi <- ggplot2::ggplot( heat_data, ggplot2::aes( x = X, y = Y, fill = r ) ) +
  ggplot2::geom_tile( color = "white", linewidth = 1.1, width = 0.98, height = 0.98 ) +
  ggplot2::geom_text( ggplot2::aes( label = Teks, color = Kontras ), size = 3.7, fontface = "bold" ) +
  ggplot2::scale_color_manual( values = c( terang = "white", gelap = "#263B3A" ), guide = "none" ) +
  ggplot2::scale_fill_gradient2( low = "#B34F55", mid = "#F7F8F7", high = "#176F63", midpoint = 0,
                                 limits = c(-1, 1), breaks = c(-1, -0.5, 0, 0.5, 1), name = "Pearson (r)" ) +
  ggplot2::coord_equal() +
  ggplot2::scale_x_discrete( position = "top" ) +
  ggplot2::labs( title = "Heatmap Korelasi Pearson", subtitle = paste(
    "Hubungan linear antar delapan variabel", "pada 56 kabupaten/kota di Kalimantan" ), x = NULL,
    y = NULL, caption = paste( "Merah = korelasi negatif |", "Putih = mendekati nol |",
                               "Hijau = korelasi positif" ) ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme( plot.background = ggplot2::element_rect( fill = "white", color = NA ),
                  panel.background = ggplot2::element_rect( fill = "white", color = NA ),
                  panel.grid = ggplot2::element_blank(),
                  axis.text.x = ggplot2::element_text( angle = 40, hjust = 0, vjust = 0, face = "bold", color = "#223D39",
                                                       size = 10 ),
                  axis.text.y = ggplot2::element_text( face = "bold", color = "#223D39", size = 10.5 ),
                  legend.position = "right",
                  plot.title = ggplot2::element_text( face = "bold", size = 17, color = "#1B3230" ),
                  plot.subtitle = ggplot2::element_text( color = "#61716F" ),
                  plot.caption = ggplot2::element_text( color = "#687A76", margin = ggplot2::margin(t = 10) ),
                  plot.margin = ggplot2::margin(22, 18, 16, 18) )
ggplot2::ggsave( filename = file.path( OUT_MAP, "36_Heatmap_Korelasi_Pearson.png" ), plot = p_korelasi,
                 width = 11, height = 9, dpi = 300, bg = "white" )
print(p_korelasi)

# 4.1.3 Gambar 4.4–4.11 — Peta Persebaran Variabel
judul("BAB 4.1.3 - GAMBAR 4.4 S.D. 4.11: PETA TEMATIK")
map_data <- sf::st_transform(data_spasial, 4326)
peta_var <- c( sanitasi = "Akses Sanitasi Layak (%)", kemiskinan = "Penduduk Miskin (%)",
               tpt = "Tingkat Pengangguran Terbuka (%)", pengeluaran_perkapita = "Pengeluaran Per Kapita (Ribu Rupiah)",
               kepadatan_penduduk = "Kepadatan Penduduk (Jiwa/km2)", air_minum = "Akses Air Minum Layak (%)",
               rls = "Rata-rata Lama Sekolah (Tahun)", uhh = "Umur Harapan Hidup (Tahun)" )
palet_hijau <- c(
  "#FFF7BC",  
  "#D9F0A3",  
  "#A1D99B",  
  "#74C476",  
  "#31A354", 
  "#006D2C"   
)
# Validasi kolom
stopifnot( all(names(peta_var) %in% names(map_data)) )
# Validasi khusus kepadatan
# Skala log10 memerlukan nilai lebih besar dari nol.
if ( any( !is.finite(map_data$kepadatan_penduduk) |
          map_data$kepadatan_penduduk <= 0 ) ) {
  stop( "Kepadatan penduduk harus berupa angka positif ", "dan tidak boleh NA/Inf untuk skala log10." )
}
for (v in names(peta_var)) {
  p <- ggplot2::ggplot(map_data) +
    ggplot2::geom_sf( ggplot2::aes(fill = .data[[v]]), color = "#34463D", linewidth = 0.18 ) +
    ggplot2::coord_sf( datum = NA ) +
    ggplot2::labs( title = peta_var[[v]], fill = NULL ) +
    ggplot2::theme_void( base_size = 12 ) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect( fill = "white", color = NA ),
      panel.background = ggplot2::element_rect( fill = "white", color = NA ),
      legend.background = ggplot2::element_rect( fill = "white", color = NA ),
      plot.title = ggplot2::element_text( hjust = 0.5, face = "bold", size = 14, color = "#203D35",
                                          margin = ggplot2::margin(b = 10) ),
      legend.position = "right",
      legend.title = ggplot2::element_text( size = 10, face = "bold" ),
      legend.text = ggplot2::element_text( size = 10 ),
      plot.margin = ggplot2::margin( 15, 15, 15, 15 ) )
  if (v == "kepadatan_penduduk") {
    batas_kepadatan <- range( map_data$kepadatan_penduduk, na.rm = TRUE )
    p <- p +
      ggplot2::scale_fill_gradientn(
        colours = palet_hijau,
        # Skala warna logaritmik
        trans = "log10",
        # Batas berdasarkan data asli
        limits = batas_kepadatan,
        # Legenda dengan nilai kepadatan asli
        breaks = c( 2, 10, 50, 200, 1000, 6000 ),
        labels = function(x) {
          format( x, big.mark = ".", decimal.mark = ",", scientific = FALSE, trim = TRUE )
        },
        name = "Jiwa/km²",
        na.value = "#D9D9D9",
        guide = ggplot2::guide_colorbar( barheight = grid::unit(6, "cm"), barwidth = grid::unit(0.7, "cm") )
      )
    # Catatan:
    # Nilai kepadatan TIDAK ditransformasi dalam data.
    # Log10 hanya diterapkan pada skala warna peta.
  } else {
    p <- p +
      ggplot2::scale_fill_gradientn(
        colours = palet_hijau,
        na.value = "#D9D9D9",
        guide = ggplot2::guide_colorbar( barheight = grid::unit(5, "cm"), barwidth = grid::unit(0.7, "cm") )
      )
  }
  indeks_label <- unique( c( which.min(map_data[[v]]), which.max(map_data[[v]]) ) )
  wilayah_label <- map_data[ indeks_label, ]
  # Titik label dihitung dalam proyeksi metrik.
  titik_label <- sf::st_transform( sf::st_point_on_surface( sf::st_transform( wilayah_label, CRS_AEQD ) ),
                                   4326 )
  p <- p +
    ggplot2::geom_sf_label( data = titik_label, ggplot2::aes(label = KABUPATEN),
                            size = 2.5, fontface = "bold",
                            color = "#17231D", fill = "white", alpha = 0.90,
                            linewidth = 0.12, label.padding = grid::unit( 0.1, "lines" ),
                            show.legend = FALSE )
  if ( requireNamespace( "ggspatial", quietly = TRUE ) ) {
    p <- p +
      ggspatial::annotation_scale( location = "bl", width_hint = 0.20 ) +
      ggspatial::annotation_north_arrow( location = "tr", which_north = "true", style =
                                           ggspatial::north_arrow_fancy_orienteering )
  }
  nama_file <- paste0( "Peta_", v, ".png" )
  ggplot2::ggsave( filename = file.path( OUT_MAP, nama_file ),
                   plot = p,
                   width = 9, height = 7, dpi = 300, bg = "white" )
  cat( "Peta selesai:", nama_file, "\n" )
}

# Lampiran 3 — Matriks Pembobot Spasial dan Evaluasi AIC ----
judul("BAB 4.2 - PEMBENTUKAN MATRIKS PEMBOBOT SPASIAL")
FORMULA <- sanitasi ~ kemiskinan + tpt + pengeluaran_perkapita +
  kepadatan_penduduk + air_minum + rls + uhh
X <- stats::model.matrix(FORMULA, data = data_df)
n <- nrow(X)
p <- ncol(X) - 1L
In <- diag(n)
stopifnot(n == 56L, p == 7L, qr(X)$rank == ncol(X))

# Persamaan (2.19): jarak Euclidean antarsentroid (meter).
dist_mat <- as.matrix(stats::dist(coords))
dimnames(dist_mat) <- list(data_df$KABUPATEN, data_df$KABUPATEN)
dist_mat_km <- dist_mat / 1000
jarak_knn <- dist_mat
diag(jarak_knn) <- Inf

buat_W <- function(k) {
  # Persamaan (2.20): matriks biner KNN.
  A_dir <- matrix(0, n, n, dimnames = dimnames(dist_mat))
  for (i in seq_len(n)) {
    m <- order(jarak_knn[i, ])[seq_len(k)]
    A_dir[i, m] <- 1
  }
  # Persamaan (2.21): simetrisasi relasi ketetanggaan.
  A_sim <- 1 * ((A_dir + t(A_dir)) > 0)
  # Persamaan (2.22): standardisasi bobot per baris.
  jumlah <- rowSums(A_sim)
  W <- sweep(A_sim, 1, jumlah, "/")
  lw <- spdep::mat2listw(W, style = "W", zero.policy = FALSE)
  list(A_dir = A_dir, A_sim = A_sim, W = W, listw = lw,
       komponen = spdep::n.comp.nb(lw$neighbours)$nc,
       min_tetangga = min(jumlah), rerata_tetangga = mean(jumlah),
       max_tetangga = max(jumlah))
}

# Log-likelihood terkonsentrasi SAR dan SEM pada parameter spasial tertentu.
# SAR: (I - rho W)Y = X beta + epsilon.
# SEM: (I - lambda W)Y = (I - lambda W)X beta + epsilon.
# Persamaan (2.46)–(2.52); AIC: Persamaan (2.56).
hitung_mle <- function(W, parameter, model = c("SAR", "SEM")) {
  model <- match.arg(model)
  A <- In - parameter * W
  AX <- if (model == "SEM") A %*% X else X
  Ay <- A %*% y
  beta <- as.vector(solve(crossprod(AX), crossprod(AX, Ay)))
  names(beta) <- colnames(X)
  galat <- as.vector(Ay - AX %*% beta)
  sigma2 <- sum(galat^2) / n
  log_det <- as.numeric(determinant(A, logarithm = TRUE)$modulus)
  LL <- -n/2 * log(2*pi) - n/2 * log(sigma2) + log_det -
    sum(galat^2) / (2*sigma2)
  K <- ncol(X) + 2L
  AIC <- -2 * LL + 2 * K
  list(beta = beta, galat = galat, sigma2 = sigma2, log_det = log_det,
       LogLik = LL, AIC = AIC, K = K)
}

# Optimasi numerik parameter spasial menggunakan spatialreg.
# Koefisien, ragam, log-likelihood, dan AIC dihitung dengan hitung_mle().
fit_spasial <- function(obj, model) {
  fit <- if (model == "SAR") {
    spatialreg::lagsarlm(FORMULA, data = data_df, listw = obj$listw,
                         method = METHOD_ML, zero.policy = FALSE)
  } else {
    spatialreg::errorsarlm(FORMULA, data = data_df, listw = obj$listw,
                           method = METHOD_ML, zero.policy = FALSE)
  }
  parameter <- if (model == "SAR") fit$rho else fit$lambda
  hasil <- hitung_mle(obj$W, parameter, model)
  stopifnot(isTRUE(all.equal(hasil$LogLik, as.numeric(logLik(fit)), tolerance = 1e-6)),
            isTRUE(all.equal(as.numeric(hasil$beta), as.numeric(coef(fit)[colnames(X)]), tolerance = 1e-6)))
  list(fit = fit, parameter = parameter, hasil = hasil)
}

# Evaluasi konektivitas dan AIC KNN simetris k = 1–10.
obj_knn <- lapply(K_EVALUASI, buat_W)
k_ringkas <- do.call(rbind, lapply(seq_along(K_EVALUASI), function(i) {
  obj <- obj_knn[[i]]
  data.frame(k = K_EVALUASI[i], Komponen_Jaringan = obj$komponen,
             Min_Tetangga = obj$min_tetangga, Rata_Tetangga = obj$rerata_tetangga,
             Max_Tetangga = obj$max_tetangga)
}))
tampil(k_ringkas, "Konektivitas KNN simetris")
fit_knn <- lapply(obj_knn, function(obj) {
  if (obj$komponen != 1L) return(NULL)
  list(SAR = fit_spasial(obj, "SAR"), SEM = fit_spasial(obj, "SEM"))
})
hasil_aic_knn <- data.frame(k = K_EVALUASI, Komponen_Jaringan = k_ringkas$Komponen_Jaringan,
                            AIC_SAR = vapply(fit_knn, function(z) if (is.null(z)) NA_real_ else z$SAR$hasil$AIC, numeric(1)),
                            AIC_SEM = vapply(fit_knn, function(z) if (is.null(z)) NA_real_ else z$SEM$hasil$AIC, numeric(1)))
baris <- hasil_aic_knn$k >= 2L
tabel_42 <- data.frame(k = hasil_aic_knn$k[baris],
                       "AIC SAR" = format_angka(hasil_aic_knn$AIC_SAR[baris]),
                       "AIC SEM" = format_angka(hasil_aic_knn$AIC_SEM[baris]), check.names = FALSE)
cetak_tabel(tabel_42, "4.2", "Perbandingan AIC Model SAR dan SEM pada KNN Simetris k = 2 sampai 10")
cat("K dengan AIC SAR minimum:", hasil_aic_knn$k[which.min(hasil_aic_knn$AIC_SAR)], "\n")
cat("K dengan AIC SEM minimum:", hasil_aic_knn$k[which.min(hasil_aic_knn$AIC_SEM)], "\n")

# Matriks bobot utama KNN simetris k = 5.
idx_k <- match(K_UTAMA, K_EVALUASI)
W_obj <- obj_knn[[idx_k]]
stopifnot(W_obj$komponen == 1L)
W <- W_obj$W
lw <- W_obj$listw
stopifnot(max(abs(rowSums(W) - 1)) < 1e-10,
          all((W > 0) == t(W > 0)), all(diag(W) == 0))
# Pemeriksaan implementasi KNN menggunakan spdep.
nb_ref <- spdep::make.sym.nb(spdep::knn2nb(spdep::knearneigh(coords, k = K_UTAMA),
                                           row.names = data_df$KABUPATEN))
W_ref <- spdep::listw2mat(spdep::nb2listw(nb_ref, style = "W", zero.policy = FALSE))
stopifnot(max(abs(W - W_ref)) < 1e-10)
if (CETAK_MATRIKS_PENUH) {
  cat("\nMatriks W (56 x 56):\n"); print(round(W, 6))
  cat("\nMatriks jarak (km):\n"); print(round(dist_mat_km, 4))
}
lihat_tetangga <- function(nama) {
  i <- which(data_df$KABUPATEN == normal_nama(nama))
  if (length(i) != 1L) stop("Wilayah tidak ditemukan atau tidak unik.")
  m <- which(W[i, ] > 0)
  data.frame(Tetangga = data_df$KABUPATEN[m], Jarak_km = dist_mat_km[i, m],
             Bobot_W = W[i, m], row.names = NULL)
}
tetangga_sambas <- lihat_tetangga("SAMBAS")
tampil(tetangga_sambas, "Tetangga dan bobot Kabupaten Sambas")

# Lampiran 4 — Autokorelasi Spasial ----
judul("BAB 4.3 - MORAN I GLOBAL AKSES SANITASI")
# Persamaan (2.33)–(2.42): Moran I, asumsi randomisasi, uji dua sisi.
hitung_moran <- function(r, W) {
  n <- length(r)
  z <- r - mean(r)
  S0 <- sum(W)
  S1 <- 0.5 * sum((W + t(W))^2)
  S2 <- sum((rowSums(W) + colSums(W))^2)
  pembilang <- as.numeric(crossprod(z, W %*% z))
  penyebut <- sum(z^2)
  I <- (n/S0) * pembilang / penyebut
  EI <- -1/(n-1)
  b2 <- n * sum(z^4) / penyebut^2
  VarI <- (n * ((n^2-3*n+3)*S1 - n*S2 + 3*S0^2) -
             b2 * ((n^2-n)*S1 - 2*n*S2 + 6*S0^2)) /
    ((n-1)*(n-2)*(n-3)*S0^2) - EI^2
  Z <- (I - EI) / sqrt(VarI)
  p_value <- 2 * stats::pnorm(abs(Z), lower.tail = FALSE)
  list(I = I, EI = EI, VarI = VarI, Z = Z, p_value = p_value,
       S0 = S0, S1 = S1, S2 = S2, b2 = b2,
       Pembilang = pembilang, Penyebut = penyebut)
}
moran_Y <- hitung_moran(y, W)
tabel_43 <- data.frame(Statistik = c("Moran’s I", "Nilai harapan E(I)", "Statistik Z", "P-value"),
                       Nilai = format_angka(c(moran_Y$I, moran_Y$EI, moran_Y$Z, moran_Y$p_value)))
cetak_tabel(tabel_43, "4.3", "Hasil Moran’s I Global Akses Sanitasi Layak")
tampil(as.data.frame(moran_Y), "Komponen perhitungan Moran I")
cat("Keputusan:", keputusan_h0(moran_Y$p_value), "\n")

# Skor Z dan lag spasialnya khusus untuk Moran Scatterplot (Gambar 4.12).
z <- (y - mean(y)) / sd(y)
wz <- as.vector(W %*% z)
# 4.3 Gambar 4.12 — Moran Scatterplot ----
data_moran <- data.frame( Z_sanitasi = as.numeric(z), Lag_Z = as.numeric(wz) )
p_scatter <- ggplot2::ggplot( data_moran, ggplot2::aes( x = Z_sanitasi, y = Lag_Z ) ) +
  ggplot2::geom_hline( yintercept = 0, linetype = "dashed", color = "#9A9A9A" ) +
  ggplot2::geom_vline( xintercept = 0, linetype = "dashed", color = "#9A9A9A" ) +
  ggplot2::geom_point( color = "#244A68", alpha = 0.78, size = 2.5 ) +
  ggplot2::geom_smooth( method = "lm", formula = y ~ x, se = FALSE, color = "#A23B32", linewidth = 0.9 ) +
  ggplot2::labs( title = paste0( "Moran Scatterplot (KNN k = ", K_UTAMA, ")" ),
                 x = "Standardisasi Sanitasi (Z)", y = "Spatial Lag dari Z" ) +
  ggplot2::theme_minimal( base_size = 12 ) +
  ggplot2::theme( plot.background = ggplot2::element_rect( fill = "white", color = NA ),
                  plot.title = ggplot2::element_text( face = "bold", hjust = 0.5 ),
                  panel.grid.minor = ggplot2::element_blank() )
ggplot2::ggsave( filename = file.path( OUT_MAP, "Moran_Scatterplot_k5.png" ),
                 plot = p_scatter,
                 width = 8, height = 6, dpi = 300, bg = "white" )


# Lampiran 5 — Estimasi OLS dan Pemeriksaan Asumsi ----
judul("BAB 4.4.1 - ESTIMASI PARAMETER OLS")
# Persamaan (2.11): beta = (X'X)^(-1) X'Y.
XtX <- crossprod(X)
XtY <- crossprod(X, y)
beta_ols <- as.vector(solve(XtX, XtY))
names(beta_ols) <- colnames(X)
yhat_ols <- as.vector(X %*% beta_ols)
e_ols <- y - yhat_ols
SSE <- sum(e_ols^2)
SST <- sum((y - mean(y))^2)
df_ols <- n - p - 1L
# Ragam untuk uji t; pembagi n-p-1, bukan n.
s2_ols <- SSE / df_ols
V_beta_ols <- s2_ols * solve(XtX)
se_ols <- sqrt(diag(V_beta_ols))
t_ols <- beta_ols / se_ols
p_t <- 2 * stats::pt(abs(t_ols), df = df_ols, lower.tail = FALSE)
ols_coef <- data.frame(Parameter = names(beta_ols), Koefisien = beta_ols,
                       Std_Error = se_ols, t_value = t_ols, p_value = p_t)
tabel_44 <- data.frame(Variabel = unname(nama_parameter[ols_coef$Parameter]),
                       Koefisien = format_angka(beta_ols), "Nilai p-value" = format_angka(p_t),
                       Keterangan = signifikansi(p_t), check.names = FALSE)
cetak_tabel(tabel_44, "4.4", "Hasil Estimasi Parameter Regresi Linear Berganda")
if (CETAK_RINCIAN_TEKNIS) tampil(ols_coef, "Koefisien, galat baku, dan statistik t OLS")

# Koefisien determinasi, uji F, log-likelihood, dan AIC.
R2 <- 1 - SSE/SST
Adjusted_R2 <- 1 - (1-R2)*(n-1)/df_ols
F_stat <- (R2/p)/((1-R2)/df_ols)
p_F <- stats::pf(F_stat, p, df_ols, lower.tail = FALSE)
s2_mle_ols <- SSE/n
LL_ols <- -n/2 * (log(2*pi) + 1 + log(s2_mle_ols))
k_ols <- ncol(X) + 1L
AIC_ols <- -2*LL_ols + 2*k_ols
ols_fit <- data.frame(R2 = R2, Adjusted_R2 = Adjusted_R2, F_stat = F_stat,
                      DF1 = p, DF2 = df_ols, p_F = p_F, AIC = AIC_ols, LogLik = LL_ols)
tampil(data.frame(R2 = format_angka(R2), Adjusted_R2 = format_angka(Adjusted_R2),
                  F_stat = format_angka(F_stat), DF1 = p, DF2 = df_ols, P_value = format_angka(p_F, 8),
                  AIC = format_angka(AIC_ols), LogLik = format_angka(LL_ols)), "Ringkasan model OLS")
cat("Keputusan uji F:", keputusan_h0(p_F), "\n")
cat("Perubahan estimasi Y (pengeluaran +Rp100.000):", format_angka(beta_ols["pengeluaran_perkapita"] * 100, 2), "poin persentase\n")
cat("Perubahan estimasi Y (air minum +5 poin; koefisien empat desimal):",
    format_angka(round(beta_ols["air_minum"], 4)*5), "poin persentase\n")

# Pemeriksaan numerik hasil OLS dan objek model untuk diagnostik residual.
ols <- stats::lm(FORMULA, data = data_df)
stopifnot(isTRUE(all.equal(beta_ols, coef(ols), tolerance = 1e-7)),
          isTRUE(all.equal(as.numeric(p_t), as.numeric(summary(ols)$coefficients[,4]), tolerance = 1e-7)))

judul("BAB 4.4.2 - UJI ASUMSI KLASIK")
# Persamaan (2.13): Studentized Breusch-Pagan = n R2 regresi bantu e^2.
e2 <- e_ols^2
beta_bantu <- solve(XtX, crossprod(X, e2))
e2_hat <- as.vector(X %*% beta_bantu)
R2_bantu <- 1 - sum((e2-e2_hat)^2)/sum((e2-mean(e2))^2)
BP <- n*R2_bantu
p_BP <- stats::pchisq(BP, df = p, lower.tail = FALSE)
tabel_45 <- data.frame("Breusch Pagan" = format_angka(BP), "P-Value" = format_angka(p_BP),
                       Keputusan = keputusan_h0(p_BP), check.names = FALSE)
cetak_tabel(tabel_45, "4.5", "Hasil Uji Heteroskedastisitas")

# Persamaan (2.12): Jarque Bera = n[S^2/6 + (K-3)^2/24].
hitung_jb <- function(r) {
  rc <- r - mean(r)
  m2 <- mean(rc^2)
  S <- mean(rc^3)/m2^(3/2)
  K <- mean(rc^4)/m2^2
  JB <- length(r)*(S^2/6 + (K-3)^2/24)
  list(S = S, K = K, JB = JB, p_value = stats::pchisq(JB, df = 2, lower.tail = FALSE))
}
jb_ols <- hitung_jb(e_ols)
tabel_46 <- data.frame("Jarque Bera" = format_angka(jb_ols$JB),
                       "P-Value" = format_angka(jb_ols$p_value), Keputusan = keputusan_h0(jb_ols$p_value), check.names = FALSE)
cetak_tabel(tabel_46, "4.6", "Hasil Uji Normalitas")
# Gambar 4.13 — Q-Q Plot Residual Model OLS
if (BUAT_QQ_OLS) {
  p_qq_ols <- ggplot2::ggplot(data.frame(Residual = e_ols),
                              ggplot2::aes(sample = Residual)) +
    ggplot2::stat_qq(color = "#244A68", size = 2.1, alpha = 0.85) +
    ggplot2::stat_qq_line(color = "#A23B32", linewidth = 0.9) +
    ggplot2::labs(title = "Q-Q Plot Residual OLS", x = "Kuantil Teoretis Normal",
                  y = "Kuantil Sampel Residual OLS") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", color = NA),
                   plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
                   panel.grid.minor = ggplot2::element_blank())
  print(p_qq_ols)
  ggplot2::ggsave(file.path(OUT_MAP, "Gambar_4_13_QQ_Plot_Residual_OLS.png"),
                  plot = p_qq_ols, width = 7, height = 5, dpi = 300, bg = "white")
}


# Moran residual OLS: koreksi nilai harapan dan varians berdasarkan model regresi.
# Statistik I dihitung dari residual; momen nol dihitung dengan lm.morantest().
I_res_ols <- (n/sum(W)) * as.numeric(crossprod(e_ols, W %*% e_ols))/sum(e_ols^2)
res_ols <- spdep::lm.morantest(ols, lw, alternative = "two.sided", zero.policy = FALSE)
EI_res_ols <- unname(res_ols$estimate[2])
VarI_res_ols <- unname(res_ols$estimate[3])
Z_res_ols <- (I_res_ols - EI_res_ols)/sqrt(VarI_res_ols)
p_res_ols <- 2*stats::pnorm(abs(Z_res_ols), lower.tail = FALSE)
stopifnot(isTRUE(all.equal(as.numeric(Z_res_ols),as.numeric(res_ols$statistic),tolerance = 1e-7)))
tabel_47 <- data.frame(Pengujian = "Moran’s I Residual OLS", "Z-hitung" = format_angka(Z_res_ols),
                       "P-Value" = format_angka(p_res_ols), Keputusan = keputusan_h0(p_res_ols), check.names = FALSE)
cetak_tabel(tabel_47, "4.7", "Hasil Uji Autokorelasi Spasial Residual")

# Persamaan (2.14)–(2.17): VIF dari regresi bantu setiap prediktor.
urutan_vif <- colnames(X)[-1]
vif_detail <- do.call(rbind, lapply(urutan_vif, function(v) {
  xj <- X[, v]
  X_bantu <- X[, colnames(X) != v, drop = FALSE]
  b <- solve(crossprod(X_bantu), crossprod(X_bantu, xj))
  xj_hat <- as.vector(X_bantu %*% b)
  SSE_j <- sum((xj-xj_hat)^2)
  SST_j <- sum((xj-mean(xj))^2)
  R2_j <- 1-SSE_j/SST_j
  data.frame(Variabel = v, SSE = SSE_j, SST = SST_j, R2 = R2_j, VIF = 1/(1-R2_j))
}))
vifs <- setNames(vif_detail$VIF, vif_detail$Variabel)
nama_vif <- c("Tingkat Kemiskinan", "Tingkat Pengangguran Terbuka", "Pengeluaran per Kapita",
              "Kepadatan Penduduk", "Akses Air Minum Layak", "Rata-rata Lama Sekolah", "Umur Harapan Hidup")
tabel_48 <- data.frame(Variabel = nama_vif, VIF = format_angka(vifs),
                       Keputusan = ifelse(vifs < 10, "Tidak Terdapat Multikolinearitas", "Perlu pemeriksaan multikolinearitas"))
cetak_tabel(tabel_48, "4.8", "Hasil Uji Multikolinearitas")
if (CETAK_RINCIAN_TEKNIS) tampil(vif_detail, "Komponen VIF")

# Lampiran 6 — Uji Lagrange Multiplier ----
judul("BAB 4.4.3 - UJI LAGRANGE MULTIPLIER")
# Persamaan (2.23)–(2.32): LM Lag, LM Error, Adjusted LM Lag dan Error.
M <- In - X %*% solve(XtX, t(X))
T_LM <- sum(diag((t(W)+W) %*% W))
s2_LM <- sum(e_ols^2)/n
WXbeta <- W %*% X %*% beta_ols
D_LM <- as.numeric(crossprod(WXbeta, M %*% WXbeta))/s2_LM
lag_LM <- as.numeric(crossprod(e_ols, W %*% y))/s2_LM
error_LM <- as.numeric(crossprod(e_ols, W %*% e_ols))/s2_LM
LM_lag <- lag_LM^2/(D_LM+T_LM)
LM_error <- error_LM^2/T_LM
RLM_lag <- (lag_LM-error_LM)^2/D_LM
RLM_error <- (error_LM-T_LM/(D_LM+T_LM)*lag_LM)^2/(T_LM*(1-T_LM/(D_LM+T_LM)))
stat_LM <- c(LM_lag, LM_error, RLM_lag, RLM_error)
p_LM <- stats::pchisq(stat_LM, df = 1, lower.tail = FALSE)
rs <- data.frame(Uji = c("LM Lag", "LM Error", "Adjusted LM Lag", "Adjusted LM Error"),
                 Statistik = stat_LM, P_value = p_LM)
tabel_49 <- data.frame(Pengujian = rs$Uji, Statistik = format_angka(stat_LM),
                       "P-value" = format_angka(p_LM), Keputusan = keputusan_h0(p_LM), check.names = FALSE)
cetak_tabel(tabel_49, "4.9", "Hasil Pengujian Lagrange Multiplier (LM)")
if (CETAK_RINCIAN_TEKNIS) tampil(data.frame(T = T_LM, D = D_LM, s2 = s2_LM,
                                            Score_Lag = lag_LM, Score_Error = error_LM), "Komponen LM")

# Lampiran 7 — Estimasi dan Interpretasi SEM ----
judul("BAB 4.5.1 - ESTIMASI PARAMETER SEM")
# Hasil optimasi lambda dan matriks kovarians MLE dari spatialreg.
sem <- fit_knn[[idx_k]]$SEM$fit
s_sem <- summary(sem)
lambda <- sem$lambda
# Persamaan (2.47)–(2.52): transformasi dan estimasi MLE pada lambda optimal.
A_sem <- In - lambda * W
AX <- A_sem %*% X
AY <- A_sem %*% y
beta_sem <- as.vector(solve(crossprod(AX), crossprod(AX, AY)))
names(beta_sem) <- colnames(X)
xb <- as.vector(X %*% beta_sem)
u <- y - xb

# Galat acak = (I - lambda W)(Y - X beta).
epsilon <- as.vector(A_sem %*% u)
sigma2_mle <- sum(epsilon^2)/n
log_det_sem <- as.numeric(determinant(A_sem, logarithm = TRUE)$modulus)
LL_sem <- -n/2*log(2*pi) - n/2*log(sigma2_mle) + log_det_sem - sum(epsilon^2)/(2*sigma2_mle)
k_sem <- ncol(X) + 2L
AIC_sem <- -2*LL_sem + 2*k_sem
stopifnot(isTRUE(all.equal(sigma2_mle, as.numeric(sem$s2), tolerance = 1e-6)),
          isTRUE(all.equal(LL_sem, as.numeric(logLik(sem)), tolerance = 1e-6)))

# OPTIMASI NUMERIK LAMBDA SEM
# Menentukan interval pencarian lambda
eigen_W <- eigen(W, only.values = TRUE)$values
stopifnot(max(abs(Im(eigen_W))) < 1e-8)
eigen_W <- Re(eigen_W)
stopifnot(min(eigen_W) < 0, max(eigen_W) > 0)
batas_lambda <- c(
  1/min(eigen_W) + 1e-6,
  1/max(eigen_W) - 1e-6)

# Menyimpan riwayat evaluasi lambda
riwayat_mle_sem <- data.frame(
  Evaluasi = integer(),
  Lambda = numeric(),
  Sigma2 = numeric(),
  Log_Determinan = numeric(),
  LogLik = numeric()
)

# Fungsi objektif log-likelihood SEM
objektif_sem <- function(lam) {
  h <- hitung_mle(W, lam, "SEM")
  
  riwayat_mle_sem <<- rbind(
    riwayat_mle_sem,
    data.frame(
      Evaluasi = nrow(riwayat_mle_sem) + 1L,
      Lambda = lam,
      Sigma2 = h$sigma2,
      Log_Determinan = h$log_det,
      LogLik = h$LogLik))
  
  return(h$LogLik)}

# Memaksimumkan fungsi log-likelihood
optimasi_sem <- optimize(
  f = objektif_sem,
  interval = batas_lambda,
  maximum = TRUE,
  tol = 1e-9)

# Menampilkan riwayat evaluasi
cat("\nMENCARI LAMBDA SEM\n")

print(round(riwayat_mle_sem, 6),row.names = FALSE)

cat("\nJumlah evaluasi:",
    nrow(riwayat_mle_sem))

cat("\nLambda optimal:",
    round(optimasi_sem$maximum, 6))

cat("\nLog-likelihood maksimum:",
    round(optimasi_sem$objective, 4), "\n")

# VALIDASI HASIL OPTIMASI MLE SEM
validasi_optimasi <- data.frame( Metode = c("errorsarlm", "optimize"), Lambda = round(
    c(lambda, optimasi_sem$maximum), 6 ),
  Log_Likelihood = round(
    c(LL_sem, optimasi_sem$objective), 4 ))

cat("\nVALIDASI HASIL OPTIMASI SEM\n")
print(validasi_optimasi, row.names = FALSE)

# Galat baku MLE menggunakan matriks kovarians estimasi dari spatialreg.
se_beta_sem <- s_sem$Coef[colnames(X), 2]
se_lambda <- s_sem$lambda.se

# Persamaan (2.54)–(2.55): statistik Wald dan p-value normal dua sisi.
z_wald <- beta_sem / se_beta_sem
p_wald <- 2 * stats::pnorm(abs(z_wald), lower.tail = FALSE)
z_lambda <- lambda/se_lambda
p_lambda <- 2 * stats::pnorm(abs(z_lambda), lower.tail = FALSE)
coef_sem <- data.frame(Parameter = colnames(X), Koefisien = beta_sem,
                       Std_Error = se_beta_sem, Z_value = z_wald, P_value = p_wald)
tabel_410 <- data.frame(Variabel = c(unname(nama_parameter[colnames(X)]), "Parameter spasial (λ)"),
                        Koefisien = format_angka(c(beta_sem, lambda)), "Galat baku" = format_angka(c(se_beta_sem, se_lambda)),
                        "Nilai p-value" = format_angka(c(p_wald, p_lambda)),
                        Keterangan = signifikansi(c(p_wald, p_lambda)), check.names = FALSE)
cetak_tabel(tabel_410, "4.10", "Hasil Estimasi Parameter Model SEM")
tampil(data.frame(Lambda = lambda, Sigma2 = sigma2_mle, Log_Determinan = log_det_sem,
                  LogLik = LL_sem, AIC = AIC_sem), "Estimasi MLE SEM")
if (CETAK_RINCIAN_TEKNIS) tampil(coef_sem, "Statistik Wald SEM")

# Persamaan (4.1)–(4.2): koefisien komponen regresi dan parameter spasial.
tampil(data.frame(Parameter = colnames(X), Koefisien = format_angka(beta_sem, 6)), "Koefisien SEM")
cat("Lambda:", format_angka(lambda, 6), "\n")
judul("BAB 4.5.2 - INTERPRETASI MODEL SEM")
cat("Perubahan estimasi Y (pengeluaran +Rp100.000):", format_angka(beta_sem["pengeluaran_perkapita"]*100), "poin persentase\n")
cat("Perubahan estimasi Y (air minum +1 poin):", format_angka(beta_sem["air_minum"]), "poin persentase\n")

# Lampiran 8 — Uji Asumsi Residual SEM
judul("BAB 4.5.3 - UJI ASUMSI RESIDUAL SEM")
# Galat acak SEM dihitung pada tahap estimasi.
moran_eps <- hitung_moran(epsilon, W)
jb_eps <- hitung_jb(epsilon)
sem_diag <- data.frame(Pengujian = c("Moran’s I (Z)", "Jarque Bera"),
                       Statistik = c(moran_eps$Z, jb_eps$JB),
                       P_value = c(moran_eps$p_value, jb_eps$p_value))
tabel_411 <- data.frame(Pengujian = sem_diag$Pengujian,
                        Statistik = format_angka(sem_diag$Statistik), "P-value" = format_angka(sem_diag$P_value),
                        Keputusan = keputusan_h0(sem_diag$P_value), check.names = FALSE)
cetak_tabel(tabel_411, "4.11", "Hasil Uji Asumsi Residual SEM")
if (CETAK_RINCIAN_TEKNIS) {
  tampil(as.data.frame(moran_eps), "Komponen Moran I galat acak SEM")
  tampil(as.data.frame(jb_eps), "Komponen Jarque Bera galat acak SEM")
}

# Lampiran 9 — Pemilihan Model
judul("BAB 4.6.1 - PERBANDINGAN MODEL OLS DAN SEM")
# Persamaan (2.56) dan (4.3): AIC = -2 log L + 2K.
comp <- data.frame(Model = c("OLS", "SEM"), AIC = c(AIC_ols, AIC_sem), LogLik = c(LL_ols, LL_sem))
tabel_412 <- data.frame(Model = comp$Model, AIC = format_angka(comp$AIC),
                        "Log-likelihood" = format_angka(comp$LogLik),
                        "Parameter spasial (p-value)" = c("–", paste0("λ = ", format_angka(lambda), " (", format_angka(p_lambda), ")")),
                        check.names = FALSE)
cetak_tabel(tabel_412, "4.12", "Perbandingan OLS dan SEM")
# Persamaan (2.53) dan (4.4): LR = 2(LL_SEM - LL_OLS).
LR_sem_ols <- 2*(LL_sem-LL_ols)
df_LR <- k_sem-k_ols
p_LR <- stats::pchisq(LR_sem_ols, df = df_LR, lower.tail = FALSE)
sem_detail <- data.frame(Lambda = lambda, SE_Lambda = se_lambda, P_Wald_Lambda = p_lambda,
                         Sigma2_Galat_Acak_MLE = sigma2_mle, AIC_OLS = AIC_ols, AIC_SEM = AIC_sem,
                         Delta_AIC = AIC_ols-AIC_sem, LR_SEM_vs_OLS = LR_sem_ols, P_LR = p_LR)
cat("Jumlah parameter OLS:", k_ols, "; SEM:", k_sem, "\n")
cat("Selisih AIC OLS - SEM:", format_angka(AIC_ols-AIC_sem), "\n")
cat("LR:", format_angka(LR_sem_ols), "; df:", df_LR, "; p-value:", format_angka(p_LR),
    "; keputusan:", keputusan_h0(p_LR), "\n")
stopifnot(nrow(tabel_41)==8L, nrow(tabel_42)==9L, nrow(tabel_44)==8L,
          nrow(tabel_49)==4L, nrow(tabel_410)==9L, nrow(tabel_411)==2L, nrow(tabel_412)==2L)
cat("\nAnalisis selesai. Gambar tersimpan di:", OUT_MAP, "\n")
