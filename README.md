# Tugas-Akhir

Analisis regresi spasial akses sanitasi layak pada 56 kabupaten/kota di Pulau Kalimantan menggunakan R.

Repository ini memuat skrip analisis untuk mendukung penyusunan hasil dan pembahasan skripsi. Analisis mencakup pengolahan data wilayah, eksplorasi delapan variabel penelitian, pembentukan bobot spasial, regresi linear berganda atau Ordinary Least Squares (OLS), evaluasi Spatial Autoregressive Model (SAR), serta estimasi Spatial Error Model (SEM).

Dokumentasi ini disusun berdasarkan implementasi dalam [`KODINGAN SKRIPSI.R`](./KODINGAN%20SKRIPSI.R). Tahun 2025 mengikuti keterangan tabel dan grafik pada skrip; kode tidak memeriksa tahun melalui kolom tersendiri. Judul resmi skripsi, sumber data, dan hasil numerik penelitian tidak dicantumkan karena belum dapat dipastikan dari file R saja.

## Daftar isi

- [1. Cakupan analisis](#1-cakupan-analisis)
- [2. Isi repository dan kebutuhan berkas](#2-isi-repository-dan-kebutuhan-berkas)
- [3. Variabel dan format data Excel](#3-variabel-dan-format-data-excel)
- [4. Persyaratan shapefile dan pencocokan wilayah](#4-persyaratan-shapefile-dan-pencocokan-wilayah)
- [5. Perangkat lunak dan paket R](#5-perangkat-lunak-dan-paket-r)
- [6. Konfigurasi dan cara menjalankan](#6-konfigurasi-dan-cara-menjalankan)
- [7. Tahapan analisis dan perhitungan](#7-tahapan-analisis-dan-perhitungan)
- [8. Tabel hasil](#8-tabel-hasil)
- [9. Gambar keluaran](#9-gambar-keluaran)
- [10. Fungsi dan objek utama](#10-fungsi-dan-objek-utama)
- [11. Pemeriksaan konsistensi dalam kode](#11-pemeriksaan-konsistensi-dalam-kode)
- [12. Catatan interpretasi dan batasan](#12-catatan-interpretasi-dan-batasan)
- [13. Penanganan kendala](#13-penanganan-kendala)
- [14. Status reproduksibilitas](#14-status-reproduksibilitas)

## 1. Cakupan analisis

| Aspek | Implementasi dalam skrip |
| --- | --- |
| Unit analisis | 56 kabupaten/kota di Pulau Kalimantan |
| Cakupan provinsi | Kalimantan Barat, Kalimantan Tengah, Kalimantan Selatan, Kalimantan Timur, dan Kalimantan Utara |
| Tahun pada label hasil | 2025 |
| Variabel respons | Persentase akses sanitasi layak |
| Jumlah prediktor | Tujuh variabel |
| Model dasar | Regresi linear berganda dengan OLS |
| Model spasial pada evaluasi bobot | SAR dan SEM |
| Model spasial yang dibahas secara rinci | SEM |
| Taraf signifikansi | 10% atau `ALPHA = 0.10` |
| Bobot spasial utama | KNN dengan relasi tetangga yang disimetriskan, `k = 5`, dan standardisasi per baris |
| Evaluasi jumlah tetangga | `k = 1` sampai `k = 10`; tabel AIC menampilkan `k = 2` sampai `k = 10` |
| Pembanding model akhir | AIC, log-likelihood, dan likelihood ratio OLS–SEM |

Urutan kerja secara umum:

```text
Excel dan shapefile
        ↓
Validasi, normalisasi nama, dan penyelarasan urutan wilayah
        ↓
Statistik deskriptif, korelasi, scatterplot, dan peta
        ↓
Centroid, jarak, serta bobot KNN untuk k = 1–10
        ↓
Evaluasi konektivitas dan AIC SAR–SEM
        ↓
Penggunaan bobot utama k = 5 dan Moran's I sanitasi
        ↓
OLS, pemeriksaan asumsi, dan uji LM
        ↓
Estimasi serta interpretasi SEM
        ↓
Pemeriksaan galat SEM dan perbandingan OLS–SEM
```

## 2. Isi repository dan kebutuhan berkas

Berkas yang tersedia saat dokumentasi ini disusun:

```text
Tugas-Akhir/
├── README.md
└── KODINGAN SKRIPSI.R
```

Untuk menjalankan analisis, siapkan struktur kerja berikut. `DATA.xlsx`, seluruh komponen shapefile, dan gambar hasil belum disertakan dalam repository.

```text
Tugas-Akhir/
├── README.md
├── KODINGAN SKRIPSI.R
├── DATA.xlsx
├── shapefile/
│   ├── Kalimantan.shp
│   ├── Kalimantan.shx
│   ├── Kalimantan.dbf
│   └── Kalimantan.prj
└── HASIL_GAMBAR_BAB4/       # Dibuat oleh skrip untuk menyimpan gambar
```

Folder data sebenarnya boleh berada di lokasi lain selama `ROOT_DIR` disesuaikan. Skrip menggunakan direktori tersebut sebagai working directory melalui `setwd(ROOT_DIR)`.

## 3. Variabel dan format data Excel

### 3.1 Struktur wajib

`DATA.xlsx` dibaca menggunakan `readxl::read_excel(DATA_FILE)` tanpa menentukan sheet atau rentang secara eksplisit. Dengan pemanggilan tersebut, skrip menggunakan sheet pertama dan menganggap baris pertama sebagai nama kolom.

Data harus terdiri atas **56 baris pengamatan dan tepat 10 kolom**. Skrip mengganti nama kolom berdasarkan **posisi**, sehingga urutan berikut wajib dipertahankan meskipun judul kolom Excel berbeda.

| Posisi kolom | Nama internal | Peran | Isi dan satuan yang digunakan dalam skrip |
| --- | --- | --- | --- |
| 1 | `kab_kota` | Identitas wilayah | Nama kabupaten/kota untuk dicocokkan dengan shapefile |
| 2 | `provinsi` | Identitas provinsi | Nama atau singkatan provinsi yang dikenali |
| 3 | `sanitasi` | Y | Akses sanitasi layak, persen |
| 4 | `kemiskinan` | X1 | Penduduk miskin, persen |
| 5 | `air_minum` | X5 | Akses air minum layak, persen |
| 6 | `kepadatan_penduduk` | X4 | Kepadatan penduduk, jiwa/km² |
| 7 | `rls` | X6 | Rata-rata lama sekolah, tahun |
| 8 | `tpt` | X2 | Tingkat pengangguran terbuka, persen |
| 9 | `pengeluaran_perkapita` | X3 | Pengeluaran per kapita, rupiah sebelum konversi |
| 10 | `uhh` | X7 | Umur harapan hidup, tahun |

Urutan kolom Excel berbeda dari urutan prediktor pada model. Formula regresi yang digunakan adalah:

```r
sanitasi ~ kemiskinan + tpt + pengeluaran_perkapita +
  kepadatan_penduduk + air_minum + rls + uhh
```

### 3.2 Validasi numerik

Delapan kolom numerik dikonversi menggunakan `as.numeric()` setelah penghapusan spasi pada awal dan akhir teks. Analisis dihentikan apabila terdapat nilai nonnumerik, `NA`, `NaN`, atau `Inf`.

Pemeriksaan rentang yang tertulis secara eksplisit meliputi:

- `sanitasi` harus berada pada rentang 0–100.
- `air_minum` harus berada pada rentang 0–100.
- `pengeluaran_perkapita` harus lebih besar dari nol.
- `kepadatan_penduduk` harus lebih besar dari nol untuk skala warna peta log10.

Simpan angka sebagai nilai numerik Excel. Teks seperti `85,50`, `1.292.748`, atau angka dengan simbol `%` tidak dibersihkan secara khusus oleh skrip dan dapat gagal dikonversi. Persentase harus memakai skala 0–100; angka 85% yang disimpan Excel sebagai 0,85 akan terbaca sebagai 0,85, bukan otomatis 85.

### 3.3 Konversi pengeluaran

Sebelum analisis, kode menjalankan:

```r
data_raw$pengeluaran_perkapita <- data_raw$pengeluaran_perkapita / 1000
```

Dengan demikian, input pengeluaran diharapkan dalam rupiah dan variabel model menggunakan ribu rupiah. Contoh: Rp1.292.748 menjadi 1.292,748 ribu rupiah. Jika input sudah dalam ribu rupiah, pembagian ini akan mengubah satuan secara keliru.

Periode pengeluaran, definisi operasional lengkap, dan sumber statistik setiap variabel tidak dinyatakan dalam file R. Informasi tersebut perlu mengikuti data dan naskah penelitian yang digunakan.

## 4. Persyaratan shapefile dan pencocokan wilayah

Shapefile harus memenuhi ketentuan berikut:

1. Berkas utama bernama `Kalimantan.shp` dan berada dalam subfolder `shapefile`.
2. Komponen pendamping `.shx`, `.dbf`, dan `.prj` tersedia dengan nama dasar yang sesuai.
3. Memiliki kolom atribut `NAMOBJ` sebagai nama kabupaten/kota.
4. Memiliki tepat 56 fitur wilayah dengan nama yang unik.
5. Memiliki CRS yang terdefinisi.
6. Nama wilayahnya cocok dengan data Excel setelah normalisasi.

Fungsi `normal_nama()` mengubah teks menjadi huruf kapital, membuang spasi di tepi teks, merapatkan spasi berulang, dan menghapus titik. Fungsi ini tidak menghapus awalan seperti `KABUPATEN`, `KAB.`, atau `KOTA` secara khusus dan tidak melakukan pencocokan nama secara perkiraan. Perbedaan nama yang tersisa harus diselesaikan pada sumber data.

Skrip menampilkan wilayah yang hanya ditemukan di Excel atau hanya ditemukan di shapefile, lalu menghentikan analisis jika ada ketidakcocokan. Setelah cocok, shapefile diurutkan berdasarkan `KABUPATEN`, dan data Excel disusun ulang dengan `match()` agar setiap nilai mengacu pada geometri yang benar.

Dimensi Z/M geometri dihapus. Jika ditemukan geometri tidak valid, skrip mencoba memperbaikinya menggunakan `sf::st_make_valid()`.

Untuk peta provinsi, nama berikut dikenali setelah normalisasi dan penghapusan awalan `PROVINSI `:

| Nama provinsi | Singkatan yang dikenali |
| --- | --- |
| Kalimantan Barat | `KALBAR` |
| Kalimantan Tengah | `KALTENG` |
| Kalimantan Selatan | `KALSEL` |
| Kalimantan Timur | `KALTIM` |
| Kalimantan Utara | `KALTARA` |

## 5. Perangkat lunak dan paket R

Gunakan R yang mendukung operator pipe bawaan `|>`; sintaks tersebut memerlukan R 4.1 atau lebih baru. Versi minimum setiap paket belum ditetapkan dalam repository. RStudio dapat digunakan untuk membuka dan menjalankan skrip.

| Paket | Pemakaian dalam kode |
| --- | --- |
| `readxl` | Membaca data Excel |
| `dplyr` | Memilih, mengelompokkan, dan merangkum geometri provinsi |
| `sf` | Membaca shapefile, memeriksa geometri, mengubah CRS, dan menghitung centroid atau titik label |
| `ggplot2` | Menyusun serta menyimpan grafik dan peta |
| `spdep` | Objek ketetanggaan, bobot spasial, konektivitas jaringan, dan Moran residual OLS |
| `spatialreg` | Estimasi SAR dan SEM |
| `ggspatial` | Skala peta dan penunjuk arah utara |

Instal paket melalui konsol R:

```r
install.packages(c(
  "readxl", "dplyr", "sf", "ggplot2",
  "spdep", "spatialreg", "ggspatial"
))
```

Fungsi dari `stats` dan `grid` juga digunakan; keduanya merupakan bagian dari distribusi R. Skrip memeriksa keberadaan paket dan berhenti jika ada paket yang belum terpasang. Walaupun anotasi peta memakai pemeriksaan `requireNamespace()`, `ggspatial` tetap termasuk dalam daftar paket wajib pada awal skrip.

## 6. Konfigurasi dan cara menjalankan

### 6.1 Mengatur direktori

Clone repository, lalu siapkan data dan shapefile:

```powershell
git clone https://github.com/ajengputri077/Tugas-Akhir.git
cd Tugas-Akhir
```

Buka `KODINGAN SKRIPSI.R` dan ubah `ROOT_DIR` agar menunjuk folder yang memuat `DATA.xlsx` dan folder `shapefile`. Nilai bawaan masih mengarah ke direktori lokal pembuat skrip:

```r
ROOT_DIR <- "C:/Users/AJENG/OneDrive/Dokumen/BISMILLAH SKRIPSI/KODINGAN"
```

Sebagai contoh, jika seluruh berkas disiapkan di folder skrip pada komputer lain:

```r
ROOT_DIR <- "E:/ANYTHING/TA Ajeng"
```

Contoh tersebut hanya dapat dipakai setelah berkas input benar-benar tersedia pada lokasi tersebut.

### 6.2 Parameter utama

| Parameter | Nilai bawaan | Kegunaan |
| --- | --- | --- |
| `ALPHA` | `0.10` | Batas p-value untuk keputusan pengujian |
| `K_UTAMA` | `5L` | Nilai k untuk bobot analisis utama |
| `K_EVALUASI` | `1:10` | Kandidat k yang dibentuk dan dievaluasi |
| `METHOD_ML` | `"eigen"` | Metode komputasi pada estimator spasial |
| `CETAK_DATA_LENGKAP` | `FALSE` | Menampilkan seluruh data 56 wilayah |
| `CETAK_MATRIKS_PENUH` | `TRUE` | Menampilkan matriks W dan jarak berukuran 56 × 56 |
| `CETAK_RINCIAN_TEKNIS` | `FALSE` | Menampilkan sejumlah komponen perhitungan tambahan |
| `BUAT_QQ_OLS` | `TRUE` | Membuat, menampilkan, dan menyimpan Q-Q plot OLS |

`K_UTAMA` harus termasuk dalam `K_EVALUASI` dan jaringan bobotnya harus terhubung. Mengubah jumlah wilayah atau rentang evaluasi memerlukan penyesuaian lebih luas karena terdapat pemeriksaan jumlah baris dan label hasil yang tetap.

### 6.3 Menjalankan analisis

Dari RStudio, buka skrip dan jalankan seluruh isi file secara berurutan menggunakan **Source**. Alternatif dari konsol R, jika working directory awal berada di folder repository:

```r
source("KODINGAN SKRIPSI.R", encoding = "UTF-8")
```

Dari terminal pada folder repository, jika `Rscript` tersedia di PATH:

```powershell
Rscript "KODINGAN SKRIPSI.R"
```

Selama proses berlangsung, hasil tabel dan ringkasan dicetak ke konsol. Gambar disimpan ke `HASIL_GAMBAR_BAB4` di dalam `ROOT_DIR`.

## 7. Tahapan analisis dan perhitungan

### 7.1 Eksplorasi data

Bagian eksplorasi menghasilkan peta wilayah penelitian, statistik deskriptif, scatterplot sanitasi terhadap tujuh prediktor, heatmap korelasi Pearson delapan variabel, dan delapan peta tematik.

Statistik deskriptif meliputi N, minimum, rata-rata, median, simpangan baku sampel, dan maksimum. Tabel 4.1 mencetak semua ukuran tersebut kecuali N. Scatterplot menampilkan garis regresi linear sederhana serta korelasi Pearson setiap prediktor dengan sanitasi.

Peta wilayah memberi warna berdasarkan provinsi. Peta tematik menggunakan skala warna kontinu dan memberi label pada wilayah dengan nilai minimum serta maksimum. Khusus kepadatan penduduk, log10 diterapkan pada **skala warna peta**; data yang masuk ke model tetap menggunakan nilai kepadatan asli.

### 7.2 Koordinat, jarak, dan bobot spasial

Centroid dihitung setelah data diproyeksikan menggunakan Azimuthal Equidistant dengan konfigurasi:

```text
+proj=aeqd +lat_0=0 +lon_0=114 +datum=WGS84 +units=m +no_defs
```

Jarak antarsentroid dihitung sebagai jarak Euclidean dalam koordinat proyeksi, kemudian dibagi 1.000 untuk tampilan kilometer. Peta ditransformasikan ke EPSG:4326 untuk visualisasi.

Untuk setiap k, fungsi `buat_W()` melakukan tahapan berikut:

1. Mengabaikan hubungan wilayah dengan dirinya sendiri dengan mengisi diagonal jarak pencarian sebagai `Inf`.
2. Memilih k tetangga terdekat untuk setiap wilayah dan membentuk matriks biner berarah `A_dir`.
3. Menyimetriskan relasi: pasangan menjadi tetangga jika salah satu arah pada `A_dir` bernilai 1.
4. Membentuk matriks biner `A_sim`.
5. Membagi setiap baris `A_sim` dengan jumlah tetangganya untuk memperoleh `W`.
6. Mengubah bobot menjadi objek `listw` dan menghitung komponen jaringan.

Bentuk bobot yang digunakan:

```text
A_sim[i,j] = 1 jika A_dir[i,j] = 1 atau A_dir[j,i] = 1
W[i,j]     = A_sim[i,j] / jumlah tetangga wilayah i
W[i,i]     = 0
```

Relasi ketetanggaan bersifat simetris, tetapi nilai numerik W tidak harus simetris setelah standardisasi per baris. Jumlah setiap baris W adalah 1. Setelah simetrisasi, satu wilayah dapat memiliki lebih dari k tetangga.

### 7.3 Evaluasi k dan AIC SAR–SEM

Skrip membentuk bobot untuk k = 1–10 dan menampilkan jumlah komponen jaringan serta minimum, rata-rata, dan maksimum jumlah tetangga. SAR dan SEM hanya diestimasi pada kandidat yang memiliki tepat satu komponen jaringan. Kandidat yang tidak terhubung menerima nilai AIC `NA`.

Tabel 4.2 menampilkan k = 2–10. Nilai k dengan AIC SAR minimum dan AIC SEM minimum dicetak ke konsol. **Bobot utama tetap mengikuti `K_UTAMA = 5L`**; kode tidak mengganti k utama secara otomatis berdasarkan AIC minimum.

### 7.4 Moran's I global sanitasi

Fungsi `hitung_moran()` menghitung Moran's I beserta nilai harapan, varians berdasarkan asumsi randomisasi, statistik Z, dan p-value normal dua sisi.

```text
z = y − rata-rata(y)
I = (n / S0) × (z'Wz / z'z)
E(I) = −1 / (n − 1)
Z = [I − E(I)] / akar[Var(I)]
```

Komponen `S0`, `S1`, `S2`, kurtosis `b2`, pembilang, dan penyebut juga disimpan. Moran scatterplot menggunakan sanitasi yang distandardisasi dengan simpangan baku sampel serta lag spasialnya `Wz`.

### 7.5 Estimasi OLS

Koefisien OLS dihitung secara matriks:

```text
β_OLS = (X'X)^−1 X'y
y_hat = Xβ_OLS
e_OLS = y − y_hat
```

Matriks X terdiri atas konstanta dan tujuh prediktor, sehingga berukuran 56 × 8. Skrip menghitung galat baku, statistik t, p-value dua sisi, R², adjusted R², uji F, log-likelihood, dan AIC.

Ragam untuk inferensi koefisien memakai `SSE / (n − p − 1)`, sedangkan ragam MLE untuk log-likelihood memakai `SSE / n`. Dengan n = 56 dan p = 7, derajat bebas residual adalah 48. Hasil koefisien serta p-value diperiksa terhadap `stats::lm()`.

### 7.6 Pemeriksaan OLS

| Pemeriksaan | Implementasi |
| --- | --- |
| Heteroskedastisitas | Studentized Breusch–Pagan melalui regresi bantu kuadrat residual, statistik `n × R²`, dan p-value chi-square dengan 7 derajat bebas |
| Normalitas | Jarque–Bera dari skewness dan kurtosis residual, p-value chi-square dengan 2 derajat bebas |
| Visualisasi normalitas | Q-Q plot residual OLS jika `BUAT_QQ_OLS = TRUE` |
| Autokorelasi spasial residual | Moran residual dengan nilai harapan dan varians dari `spdep::lm.morantest()`, alternatif dua sisi |
| Multikolinearitas | VIF setiap prediktor melalui regresi bantu terhadap prediktor lain dan konstanta |

Untuk VIF, label pada kode menggunakan batas 10: VIF di bawah 10 diberi keterangan `Tidak Terdapat Multikolinearitas`, sedangkan nilai 10 atau lebih diberi keterangan `Perlu pemeriksaan multikolinearitas`.

### 7.7 Uji Lagrange Multiplier

Empat statistik dihitung dari model OLS dan bobot utama:

- LM Lag.
- LM Error.
- Adjusted LM Lag, disimpan sebagai `RLM_lag`.
- Adjusted LM Error, disimpan sebagai `RLM_error`.

Perhitungan menggunakan matriks proyeksi residual `M`, komponen `T_LM`, `D_LM`, skor lag, dan skor error. P-value keempat pengujian memakai distribusi chi-square dengan satu derajat bebas.

Hasil LM dicetak sebagai bahan evaluasi. Skrip tetap melanjutkan estimasi dan pembahasan SEM; belum ada percabangan yang memilih SAR atau SEM secara otomatis berdasarkan keputusan LM.

### 7.8 Estimasi SEM dan optimasi lambda

Model SEM yang diimplementasikan:

```text
y = Xβ + u
u = λWu + ε
ε = (I − λW)(y − Xβ)
```

Estimasi awal menggunakan `spatialreg::errorsarlm()` pada bobot utama. Dengan lambda hasil estimator tersebut, kode membentuk `A = I − λW`, menghitung `AX` dan `Ay`, lalu menghitung ulang koefisien serta ukuran kecocokan:

```text
β_SEM = [(AX)'(AX)]^−1 (AX)'(Ay)
σ²_MLE = ε'ε / n
log L = −(n/2) log(2π) − (n/2) log(σ²)
        + log|I − λW| − ε'ε / (2σ²)
```

Fungsi `hitung_mle()` juga digunakan untuk perhitungan SAR pada evaluasi bobot. Untuk SAR, transformasi diterapkan pada Y sementara matriks prediktor tetap X.

Skrip kemudian mengoptimalkan kembali lambda menggunakan `optimize(maximum = TRUE, tol = 1e-9)`. Interval pencarian dibentuk dari kebalikan nilai eigen minimum dan maksimum W dengan penyesuaian `1e-6` pada kedua batas. Setiap evaluasi menyimpan lambda, sigma², log determinan, dan log-likelihood pada `riwayat_mle_sem`.

Hasil `errorsarlm` dan `optimize` ditampilkan berdampingan. Tabel tersebut merupakan perbandingan tercetak; kesamaan kedua hasil optimasi tidak dipaksakan melalui `stopifnot()`. Koefisien akhir tetap menggunakan lambda dari `errorsarlm`, dan galat bakunya berasal dari ringkasan model `spatialreg`. Uji Wald koefisien dan lambda menggunakan p-value normal dua sisi.

### 7.9 Interpretasi perubahan prediktor

Skrip mencetak beberapa contoh perubahan estimasi sanitasi:

| Model | Perubahan prediktor | Perhitungan yang dicetak |
| --- | --- | --- |
| OLS | Pengeluaran naik Rp100.000 | Koefisien pengeluaran × 100 |
| OLS | Akses air minum naik 5 poin persentase | Koefisien air minum dibulatkan ke empat desimal, lalu × 5 |
| SEM | Pengeluaran naik Rp100.000 | Koefisien pengeluaran × 100 |
| SEM | Akses air minum naik 1 poin persentase | Koefisien air minum |

Faktor 100 berasal dari penggunaan ribu rupiah pada variabel pengeluaran. Perubahan estimasi Y dinyatakan dalam **poin persentase** sanitasi, dengan prediktor lain dianggap tetap. Koefisien SEM dibahas sebagai bagian regresi `Xβ`; lambda adalah parameter ketergantungan pada komponen error.

### 7.10 Pemeriksaan galat SEM

Kode membedakan dua komponen:

- `u = y − Xβ`, yaitu penyimpangan terhadap komponen regresi.
- `epsilon = (I − λW)u`, yaitu galat setelah penyaringan spasial.

Pengujian Tabel 4.11 diterapkan pada `epsilon`, menggunakan `hitung_moran()` dan `hitung_jb()`. Implementasi Moran ini berbeda dari pemeriksaan residual OLS yang mengambil momen dari `lm.morantest()`. Bagian pemeriksaan SEM tersebut memuat Moran dan Jarque–Bera; tidak memuat pengujian heteroskedastisitas SEM.

### 7.11 Perbandingan OLS dan SEM

Kode menghitung AIC dengan rumus:

```text
AIC = −2 log L + 2K
```

Jumlah parameter yang digunakan adalah 9 untuk OLS, terdiri atas delapan koefisien termasuk konstanta dan satu ragam, serta 10 untuk SEM, dengan tambahan lambda.

Perbandingan akhir juga memuat:

```text
Delta AIC = AIC_OLS − AIC_SEM
LR = 2 × (log L_SEM − log L_OLS)
```

P-value LR dihitung dengan chi-square satu derajat bebas. Skrip mencetak ukuran pembanding serta keputusan pengujian; tidak membuat objek keputusan tunggal yang secara otomatis menyatakan model terbaik.

## 8. Tabel hasil

Seluruh tabel berikut dicetak ke konsol. Skrip belum mengekspornya secara otomatis menjadi CSV, Excel, Word, atau PDF.

| Nomor | Objek | Isi |
| --- | --- | --- |
| 4.1 | `tabel_41` | Statistik deskriptif delapan variabel |
| 4.2 | `tabel_42` | AIC SAR dan SEM pada k = 2–10 |
| 4.3 | `tabel_43` | Moran's I global sanitasi, nilai harapan, Z, dan p-value |
| 4.4 | `tabel_44` | Koefisien OLS, p-value, dan signifikansi |
| 4.5 | `tabel_45` | Uji heteroskedastisitas Breusch–Pagan |
| 4.6 | `tabel_46` | Uji normalitas Jarque–Bera OLS |
| 4.7 | `tabel_47` | Uji autokorelasi spasial residual OLS |
| 4.8 | `tabel_48` | VIF dan keterangan setiap prediktor |
| 4.9 | `tabel_49` | LM Lag, LM Error, Adjusted LM Lag, dan Adjusted LM Error |
| 4.10 | `tabel_410` | Koefisien SEM dan lambda, galat baku, p-value, dan signifikansi |
| 4.11 | `tabel_411` | Moran dan Jarque–Bera galat SEM |
| 4.12 | `tabel_412` | AIC, log-likelihood, dan informasi lambda pada perbandingan OLS–SEM |

Ringkasan tambahan mencakup konektivitas KNN, komponen Moran, ringkasan OLS, tetangga Kabupaten Sambas, riwayat optimasi lambda, serta nilai LR. Fungsi `tampil()` hanya mencetak objek; keberadaan pengolahan akhiran `.csv` pada label fungsi tersebut tidak berarti berkas CSV ditulis.

## 9. Gambar keluaran

Dengan pengaturan bawaan dan analisis yang berhasil hingga akhir, skrip menyimpan **13 berkas PNG** pada `HASIL_GAMBAR_BAB4`.

| Berkas | Isi | Ukuran dan resolusi |
| --- | --- | --- |
| `Gambar_4_1_Peta_Provinsi_Kalimantan.png` | Peta wilayah dengan warna provinsi | 11 × 7,5 inci; 350 dpi |
| `34_Scatterplot_Hubungan_Y_dan_7X.png` | Scatterplot sanitasi terhadap tujuh prediktor | 10 × 12 inci; 350 dpi |
| `36_Heatmap_Korelasi_Pearson.png` | Heatmap korelasi delapan variabel | 11 × 9 inci; 300 dpi |
| `Peta_sanitasi.png` | Persebaran akses sanitasi layak | 9 × 7 inci; 300 dpi |
| `Peta_kemiskinan.png` | Persebaran penduduk miskin | 9 × 7 inci; 300 dpi |
| `Peta_tpt.png` | Persebaran tingkat pengangguran terbuka | 9 × 7 inci; 300 dpi |
| `Peta_pengeluaran_perkapita.png` | Persebaran pengeluaran per kapita | 9 × 7 inci; 300 dpi |
| `Peta_kepadatan_penduduk.png` | Persebaran kepadatan dengan skala warna log10 | 9 × 7 inci; 300 dpi |
| `Peta_air_minum.png` | Persebaran akses air minum layak | 9 × 7 inci; 300 dpi |
| `Peta_rls.png` | Persebaran rata-rata lama sekolah | 9 × 7 inci; 300 dpi |
| `Peta_uhh.png` | Persebaran umur harapan hidup | 9 × 7 inci; 300 dpi |
| `Moran_Scatterplot_k5.png` | Sanitasi terstandardisasi dan lag spasialnya | 8 × 6 inci; 300 dpi |
| `Gambar_4_13_QQ_Plot_Residual_OLS.png` | Q-Q plot residual OLS | 7 × 5 inci; 300 dpi |

Jika `BUAT_QQ_OLS = FALSE`, Q-Q plot tidak dibuat pada eksekusi tersebut. Nama berkas Moran masih mengandung `k5` secara tetap meskipun `K_UTAMA` diubah. Menjalankan ulang skrip pada folder yang sama menggunakan kembali nama keluaran tersebut dan dapat menimpa gambar sebelumnya.

## 10. Fungsi dan objek utama

### 10.1 Fungsi

| Fungsi | Kegunaan |
| --- | --- |
| `tampil()` | Mencetak objek dengan label |
| `judul()` | Mencetak pemisah judul bagian analisis |
| `format_angka()` | Membulatkan dan memformat angka dengan titik ribuan serta koma desimal; `NA` ditampilkan sebagai tanda pisah |
| `cetak_tabel()` | Mencetak nomor, judul, dan isi tabel |
| `keputusan_h0()` | Memberi keputusan berdasarkan `p < ALPHA` |
| `signifikansi()` | Memberi label signifikansi berdasarkan `p < ALPHA` |
| `normal_nama()` | Menormalisasi nama wilayah dan provinsi |
| `pearson()` | Menghitung korelasi Pearson secara langsung |
| `buat_W()` | Membentuk bobot KNN, objek `listw`, dan ringkasan konektivitas |
| `hitung_mle()` | Menghitung koefisien, galat, ragam, log-likelihood, dan AIC SAR/SEM pada parameter spasial tertentu |
| `fit_spasial()` | Menjalankan estimator spasial dan memeriksa hasil terhadap perhitungan matriks |
| `lihat_tetangga()` | Menampilkan nama tetangga, jarak kilometer, dan bobot sebuah wilayah |
| `hitung_moran()` | Menghitung Moran's I, momen, Z, dan p-value |
| `hitung_jb()` | Menghitung skewness, kurtosis, Jarque–Bera, dan p-value |
| `objektif_sem()` | Mengevaluasi log-likelihood SEM sekaligus menyimpan riwayat optimasi |

Setelah analisis berhasil dijalankan dalam sesi R, contoh pemeriksaan tetangga:

```r
lihat_tetangga("SAMBAS")
```

Nama yang dimasukkan harus cocok dengan nama wilayah hasil normalisasi. Skrip juga memanggil contoh Sambas secara langsung saat analisis berjalan.

### 10.2 Objek analisis

| Objek | Isi |
| --- | --- |
| `data_raw` | Data Excel setelah penamaan, validasi, dan konversi satuan |
| `data_spasial` | Data penelitian yang digabungkan dengan geometri |
| `data_df` | Atribut tanpa geometri, termasuk koordinat centroid |
| `coords`, `dist_mat`, `dist_mat_km` | Koordinat dan matriks jarak |
| `X`, `y`, `In` | Matriks desain, respons, dan matriks identitas |
| `obj_knn`, `k_ringkas` | Bobot serta ringkasan jaringan seluruh kandidat k |
| `fit_knn`, `hasil_aic_knn` | Model SAR/SEM dan AIC setiap kandidat |
| `W`, `lw` | Bobot utama dalam bentuk matriks dan `listw` |
| `ols`, `beta_ols`, `e_ols`, `ols_fit` | Model, koefisien, residual, dan ringkasan OLS |
| `rs`, `vif_detail` | Hasil LM dan rincian VIF |
| `sem`, `beta_sem`, `lambda` | Model SEM dan parameter estimasinya |
| `u`, `epsilon` | Penyimpangan regresi dan galat tersaring SEM |
| `riwayat_mle_sem`, `optimasi_sem`, `validasi_optimasi` | Riwayat dan hasil optimasi tambahan |
| `comp`, `sem_detail` | Ukuran perbandingan OLS–SEM dan rincian SEM |

## 11. Pemeriksaan konsistensi dalam kode

Skrip memiliki sejumlah pemeriksaan `stop()` dan `stopifnot()` yang dijalankan saat analisis berlangsung:

- Keberadaan direktori, Excel, shapefile utama, dan paket R.
- Jumlah kolom, jumlah pengamatan, nama wilayah unik, kelengkapan nilai, dan beberapa batas nilai variabel.
- Kesesuaian nama dan urutan data Excel dengan shapefile.
- Ketersediaan CRS, jumlah centroid, serta rank penuh matriks X.
- Jaringan bobot utama memiliki tepat satu komponen.
- Jumlah setiap baris W mendekati 1, diagonal W nol, dan relasi tetangga simetris.
- Bobot KNN utama cocok dengan konstruksi pembanding `knearneigh()`, `knn2nb()`, dan `make.sym.nb()` dari `spdep`.
- Koefisien dan log-likelihood SAR/SEM hasil perhitungan matriks cocok dengan estimator paket pada toleransi `1e-6`.
- Koefisien dan p-value OLS cocok dengan `lm()` pada toleransi `1e-7`.
- Statistik Z Moran residual OLS cocok dengan keluaran `lm.morantest()` pada toleransi `1e-7`.
- Ragam MLE dan log-likelihood SEM cocok dengan objek `errorsarlm` pada toleransi `1e-6`.
- Nilai eigen W memenuhi pemeriksaan untuk pembentukan interval optimasi.
- Jumlah baris beberapa tabel akhir sesuai struktur hasil yang diharapkan.

Keberadaan pemeriksaan ini tidak berarti seluruh pemeriksaan telah lulus pada lingkungan pengguna. Bukti keberhasilan memerlukan eksekusi dengan data penelitian yang sebenarnya.

## 12. Catatan interpretasi dan batasan

1. **Hasil numerik belum tersedia di README.** Nilai koefisien, tanda hubungan, p-value, AIC, lambda, dan model yang lebih sesuai harus diambil dari eksekusi analisis; angka-angka tersebut tidak dapat disimpulkan hanya dari struktur kode.
2. **Tahun dan sumber data belum divalidasi oleh kode.** Label menyebut 2025, tetapi tidak ada kolom tahun atau metadata sumber yang diperiksa.
3. **k utama ditetapkan sebelumnya.** Evaluasi AIC tidak otomatis mengganti k = 5 dan tidak membuktikan bahwa nilai tersebut merupakan minimum sebelum hasil diperiksa.
4. **Pembahasan SEM sudah ditentukan dalam alur.** Uji LM tidak mengendalikan pemilihan model secara programatis.
5. **Keputusan memakai p-value mentah.** Label didasarkan pada `p < 0.10`, sedangkan angka yang dicetak umumnya dibulatkan ke empat desimal. Tampilan `0,0000` adalah hasil pembulatan, bukan bukti probabilitas tepat nol.
6. **Peta dan model memakai perlakuan kepadatan yang berbeda.** Log10 hanya mengubah pemetaan warna. Prediktor kepadatan dalam OLS, SAR, dan SEM tidak ditransformasi log.
7. **Scatterplot membatasi tampilan Y pada 60–100.** Pembatasan memakai `coord_cartesian()`; titik di luar rentang tersebut dapat tidak terlihat meskipun datanya tetap dipakai dalam perhitungan.
8. **Warning disembunyikan secara global.** Baris pertama memakai `options(warn = -1)`. Untuk meninjau warning saat pemeriksaan, ubah baris tersebut menjadi `options(warn = 0)`; pengaturan sebelum `source()` saja akan ditimpa oleh skrip.
9. **Sebagian konfigurasi masih tetap.** Jumlah wilayah 56, jumlah prediktor tujuh, beberapa nomor tabel, nama file, serta contoh wilayah Sambas terkait dengan penelitian ini.
10. **Metode inferensi perlu dibaca sesuai implementasinya.** Moran galat SEM memakai fungsi Moran umum dengan asumsi randomisasi, sedangkan Moran residual OLS memakai momen berbasis regresi. README mendokumentasikan perbedaan tersebut tanpa mengklaim validasi metodologis tambahan.
11. **Analisis bukan bukti sebab-akibat dengan sendirinya.** Interpretasi perubahan prediktor mengikuti persamaan regresi yang dipasang dan perlu dibahas bersama rancangan serta konteks penelitian.
12. **Lingkungan belum dikunci.** Repository belum memiliki lockfile paket, daftar versi yang telah diuji, pengujian otomatis terpisah, atau ekspor model dan tabel secara otomatis.

## 13. Penanganan kendala

| Pesan atau gejala | Bagian yang perlu diperiksa |
| --- | --- |
| `Folder KODINGAN tidak ditemukan` | Sesuaikan `ROOT_DIR` dengan lokasi berkas input |
| `DATA.xlsx tidak ditemukan` | Pastikan nama dan lokasi Excel berada langsung di `ROOT_DIR` |
| `Shapefile tidak ditemukan` | Periksa subfolder `shapefile` dan nama `Kalimantan.shp` beserta berkas pendamping |
| `Paket R belum terpasang` | Instal seluruh paket yang disebutkan sebelum menjalankan ulang |
| Excel tidak memiliki tepat 10 kolom | Hapus kolom tambahan yang ikut terbaca dan sesuaikan urutan kolom |
| Jumlah baris atau fitur bukan 56 | Periksa cakupan wilayah, baris kosong, duplikasi, serta isi shapefile |
| `Nilai tidak numerik/NA` | Periksa baris Excel yang dicetak dan format numerik sel tersebut |
| `Nama wilayah tidak cocok` | Cocokkan daftar Excel dan `NAMOBJ`, termasuk awalan nama dan ejaan |
| Nama wilayah duplikat | Pastikan satu pengamatan dan satu fitur untuk setiap wilayah |
| `CRS shapefile tidak didefinisikan` | Periksa berkas `.prj` dan metadata CRS sumber |
| `Nama provinsi tidak dikenali` | Gunakan nama atau singkatan yang tercantum pada bagian persyaratan provinsi |
| Kepadatan tidak positif | Periksa nol, nilai negatif, dan nilai tidak terhingga sebelum pemetaan log10 |
| Pemeriksaan `stopifnot()` gagal | Periksa ekspresi yang gagal, kecocokan data, konektivitas bobot, rank X, dan hasil perhitungan pembanding |
| Konsol sangat panjang | Ubah `CETAK_MATRIKS_PENUH` menjadi `FALSE` |
| Hasil tabel tidak muncul sebagai file | Tabel hanya dicetak ke konsol dan disimpan sebagai objek sesi R |

Perubahan data atau konfigurasi sebaiknya diikuti eksekusi dari awal agar urutan wilayah, matriks bobot, model, dan tabel tetap berasal dari pengaturan yang sama.

## 14. Status reproduksibilitas

README ini mendokumentasikan isi skrip, bukan laporan hasil eksekusi. Analisis belum dijalankan dalam proses penyusunan dokumentasi karena `DATA.xlsx` dan shapefile tidak tersedia pada folder repository yang diperiksa.

Untuk mereproduksi penelitian, diperlukan data dengan struktur yang dijelaskan, shapefile wilayah yang sesuai, konfigurasi direktori yang benar, serta paket R yang kompatibel. Keberhasilan eksekusi penuh ditandai oleh tercapainya pesan akhir `Analisis selesai. Gambar tersimpan di:` setelah seluruh pemeriksaan kode dilewati.

Setelah menjalankan analisis, informasi lingkungan dapat dicatat secara manual dari konsol R:

```r
sessionInfo()
```

Repository belum memuat berkas lisensi. Sumber data, ketentuan penggunaan data, judul resmi penelitian, serta ketentuan penggunaan ulang kode perlu ditetapkan oleh pemilik repository berdasarkan dokumen penelitian dan hak yang berlaku.
