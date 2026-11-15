@echo off
echo Mengganti file laporan dengan versi revisi...
copy /Y "Laporan Ujikom Muhammad Nazril Putra Natrabu XII PPLG 2_Revisi.docx" "Laporan Ujikom Muhammad Nazril Putra Natrabu XII PPLG 2.docx"
if %errorlevel% equ 0 (
    echo [SUKSES] Laporan berhasil diperbarui!
) else (
    echo [GAGAL] File masih terbuka di WPS Office. Silakan tutup WPS Office terlebih dahulu lalu jalankan kembali script ini.
)
pause
