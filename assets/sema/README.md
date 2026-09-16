# Salon Şeması Görsel Kütüphanesi

Buraya PNG bırak → Garson Performansı ısı haritası o parçayı **gerçek görselle** çizer.
Dosya yoksa otomatik olarak mevcut çizim (vektör) kullanılır. Yani istediğin kadarını ver.

## EN ÖNEMLİ: combo masa görseli (masa + sandalyeler tek PNG)

Isı haritası için detay şart değil. En pratik yol: **masa + 4 sandalyesi birlikte tek kare PNG**.
Bu görsel her masaya basılır ve ekrandaki **− / +** boyut ayarıyla büyütülüp küçültülür (kalıcı).

| Dosya                 | Ne                                   | Not |
|-----------------------|--------------------------------------|-----|
| `masa_kare.png`       | **Kare masa + 4 sandalye** (üstten)  | ANA görsel. Kare tuval, ortalı |
| `masa_yuvarlak.png`   | Yuvarlak masa + sandalyeler (üstten) | Opsiyonel; yoksa masa_kare kullanılır değil → yuvarlak masalar vektör |

> masa_kare.png / masa_yuvarlak.png **varsa** o masada ayrı sandalye çizilmez (görsel zaten içeriyor).
> Yoksa sistem vektör masa + kapasiteye göre sandalye çizer.

## Opsiyonel (istersen)
| Dosya | Ne |
|-------|-----|
| `zemin.png` | Zemin dokusu (parke/mermer), tekrarlanır — seamless olsun |
| `saksi.png` | Saksı/bitki |
| `bar.png` `mutfak.png` `kasa.png` `giris.png` `wc.png` `otopark.png` `depo.png` | Landmark noktaları |

## Kurallar
- **Şeffaf arka plan** (transparent PNG).
- **Üstten (kuşbakışı)** görünüm.
- Kare tuval (ör. 512×512), görsel ortalı.
- Boyut ekrandan − / + ile ayarlanır; sen tek görsel ver, ölçeği uygulamadan tuttururuz.

Dosyaları koyduktan sonra bana "koydum" de → build alıp kurarım.
