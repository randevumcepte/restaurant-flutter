# ResteOS — SepetTakip Denklik & Masaüstü Yol Haritası

SepetTakip referans alınarak ResteOS'un masaüstü (PC/tablet) sürümünün özellik denkliği.
Telefon düzeni her ekranda korunur; masaüstü = sol sabit menü + ekranı dolduran yoğun yerleşim.

## Durum özeti

| # | Özellik | Durum | Not |
|---|---------|-------|-----|
| 1 | Özet / Dashboard (masaüstü çok-sütunlu pano) | ✅ Bitti | Genişlik >=1000 → pano |
| 2 | Sol sabit menü (shell) | ✅ Bitti | Panel + Yönetim + Asistan + tema/çıkış |
| 3 | **Paket sipariş tablosu + durum akışı + otomatik onay** | 🟡 Yapılıyor | Backend `adisyonlar` + `/paket/durum` var; API+tablo yapılacak |
| 4 | Masalar + fotoğraflı menü adisyon + bölge ızgara | 🟡 | Masalar var, foto-menü + masaüstü ızgara yapılacak |
| 5 | Stok + reçete + renk kodlu kart + otomatik düşüm | 🟡 | Backend + otomatik düşüm VAR; masaüstü görsel yapılacak |
| 6 | Satın Alma / Alış Faturası | ✅ Var | |
| 7 | Personel + gruplu kart + gelişmiş yetki | ✅/🟡 | Yetki var; modül-bazlı genişletilecek (sipariş/yazıcı/iade/iskonto) |
| 8 | Cari + Gider + Avans + Nakit akış | ✅ Var | |
| 9 | Raporlar (Ciro, Grafikler, Yoğunluk, Isı) | 🟡 | Var; SepetTakip görseline çekilecek |
| 10 | Çevre Raporları (pazar/rakip kıyas) | ❌ Büyük | Ağ verisi gerekir (çok restoran) |
| 11 | Kurye Takip harita + GPS + atama | 🟡 | Backend kurye GPS altyapısı VAR (OSM/Leaflet); masaüstü ekran yapılacak |
| 12 | Platform Yönetimi + Çalışma Saatleri (aç/kapa) | 🟡 | Menü/tabela/ödeme/saat tek ekran; yeni modül |
| 13 | WhatsApp Katalog Sipariş | ❌ Büyük | Backend + WhatsApp entegrasyonu |
| 14 | ÖKC / ödeme cihazı (Ingenico/Paycell/İNPos/Beko/Pavo) | ❌ Büyük | Üretici SDK + GİB/TSM sertifikasyon; anlaşma gerekir |
| 15 | CallerID / CallerPlus (arayan tanıma) | ❌ | Hat/donanım entegrasyonu |

## ResteOS'un SepetTakip'te OLMAYAN artıları ⭐
- **QR Menü + AI müşteri asistanı** (masadan sesli/yazılı sipariş asistanı)
- **Patron AI (sesli)** — işletme sahibine proaktif içgörü + sesli sohbet

## Önerilen sıra (masaüstü görsel dili + eksik modüller)
1. **Paket sipariş tablosu** (durum akışı + aksiyon butonları + otomatik onay) ← *şu an*
2. Stok — renk kodlu kart ızgarası (backend hazır, hızlı)
3. Masalar — bölge ızgara + fotoğraflı adisyon menüsü
4. Personel — gruplu kart + genişletilmiş yetkiler
5. Raporlar — grafik/görsel güçlendirme
6. Platform Yönetimi + Çalışma Saatleri
7. Kurye harita ekranı (altyapı var)
8. (Büyük/geç) Çevre Raporları · WhatsApp katalog · ÖKC · CallerID

## Teknik notlar
- Siparişler: `adisyonlar` (kanal='paket', durum, teslimat_durumu: hazirlaniyor→hazir→yolda→teslim)
- Durum ucu (web): `POST /paket/durum` {adisyon_id, durum}; teslim → durum='odendi'+kapanis
- App uçları: `GET /api/paket`, `GET /api/paket/{id}` (token: personeller.api_token)
- Yapılacak: `POST /api/paket/durum` (token'lı) + otomatik onay ayarı + restoran aç/kapa
