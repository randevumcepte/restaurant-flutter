# Salon Şeması Görsel Kütüphanesi

Buraya PNG bırak → Garson Performansı ısı haritası o parçayı **gerçek görselle** çizer.
Dosya yoksa otomatik olarak mevcut çizim (vektör) kullanılır. Yani istediğin kadarını ver.

## Dosya isimleri (AYNEN bu adlarla koy)

| Dosya                 | Ne                          | Not |
|-----------------------|-----------------------------|-----|
| `masa_yuvarlak.png`   | Yuvarlak masa (üstten)      | Kare tuval içine ortalı |
| `masa_kare.png`       | Kare/dikdörtgen masa (üstten)| Kare tuval |
| `sandalye.png`        | TEK sandalye (üstten)       | Sırtı YUKARI baksın → sistem döndürür |
| `zemin.png`           | Zemin dokusu (parke/mermer) | Tekrarlanır (seamless/tileable olsun) |
| `saksi.png`           | Saksı/bitki (üstten)        | Küçük |
| `bar.png`             | Bar (üstten)                | Landmark |
| `mutfak.png`          | Mutfak                      | Landmark |
| `kasa.png`            | Kasa                        | Landmark |
| `giris.png`           | Giriş kapısı                | Landmark |
| `wc.png`              | WC                          | Landmark |
| `otopark.png`         | Otopark                     | Landmark |
| `depo.png`            | Depo                        | Landmark |

## Kurallar
- **Şeffaf arka plan** (transparent PNG) — masa/sandalye/landmark için şart.
- **Üstten (kuşbakışı)** görünüm — yandan değil.
- Kare tuval (ör. 512×512) önerilir; masa görseli tuvale ortalı olsun.
- `sandalye.png`: sırt/arkalık görselin ÜST kenarına baksın. Sistem her masada
  otomatik döndürür (yuvarlakta çevreye, karede 4 kenara).
- `zemin.png`: kenarları birleşen (seamless) doku olursa döşemede dikiş görünmez.

Dosyaları koyduktan sonra bana "koydum" de → tekrar build alıp kurarım.
