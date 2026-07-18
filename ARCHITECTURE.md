# Tap Spaces — native macOS

Menü çubuğu uygulaması. Masaya vurduğun bölgeyi tanır ve o bölgeye atadığın
klavye kombinasyonunu sisteme gönderir.

## Kur

```bash
./build.sh --install     # /Applications içine kurar
./build.sh               # sadece build/ içine derler
```

Sonra `TapSpaces.app`'i aç. Menü çubuğunda ✋ ikonu çıkar; Dock ikonu sadece
pencere açıkken görünür.

## İzinler

| İzin | Ne için | Nasıl |
|---|---|---|
| **Mikrofon** | Vuruşları duymak | İlk açılışta sorulur |
| **Erişilebilirlik** | Tuş göndermek **ve** ⌃← gibi sistem kombinasyonlarını kaydetmek | Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik |

Erişilebilirlik iznini verdikten sonra **uygulamayı yeniden başlat**.

### ⚠️ Yeniden derleme Erişilebilirlik iznini bozar

Uygulama ad-hoc imzalı (`codesign --sign -`). macOS bu izni **cdhash**'e bağlıyor,
cdhash da binary içeriğinden türüyor. Yani **her kod değişikliği izni geçersiz
kılar** — Ayarlar'daki satır açık görünmeye devam eder ama artık eşleşmez, ve
uygulama sessizce "tuş gönderilemedi" der.

Derledikten sonra izni geri almak için:

```bash
tccutil reset Accessibility com.mustafa.tapspaces
./build.sh --install
```

Sonra Sistem Ayarları → Erişilebilirlik → TapSpaces anahtarını tekrar aç
(Touch ID ister). macOS ad-hoc imzalı uygulamalarda otomatik izin dialogunu
göstermez, manuel açman gerekir.

Kalibrasyon bundan etkilenmez — o `~/Library/Application Support/` içinde,
uygulama imzasından bağımsız.

## Kullan

1. Bölgeye tıkla → Kalibrasyon moduna geçer
2. Masanın o noktasına 20–30 kez vur
3. Dört bölge için tekrarla
4. Her bölgenin yanındaki kutuya tıkla, atamak istediğin tuşlara bas
5. **Kısayolları çalıştır** anahtarını aç
6. **Canlı** moda geç

Ayarlar `~/Library/Application Support/TapSpaces/state.json` içinde tutulur.

## Neden %100 fizik değil

macOS, MacBook mikrofon dizisini tek beamform edilmiş kanal olarak sunuyor.
Tek kanalda varış zamanı farkı yok, yani TDOA / triangülasyon imkansız.

Bunun yerine her vuruş akustik parmak izine göre sınıflandırılıyor: mesafe
genliği ve yüksek frekans sönümünü değiştirir, her nokta masanın farklı
rezonans modlarını uyarır, direkt/yansıyan ses oranı kaynakla değişir.
Vuruş başına 56 boyutlu vektör → standartlaştırılmış öklid mesafeli k-NN (k=5).

Spektral bantların ortalaması çıkarılıyor, böylece **ne kadar sert** değil
**nereye** vurduğun ölçülüyor. `--selftest` bunu doğruluyor: aynı vuruşu 0.25×
ve 2.5× genlikle beslediğinde öznitelik kayması 0.00000.

## Sınırlar

- **Kurulum sabit olmalı.** Laptop veya masa yer değiştirirse yeniden kalibre et.
- **Masa yüzeyi önemli.** Sert, rezonanslı ahşap iyi ayrışır; kalın keçe sönümler.
- **Sol/sağ > üst/alt.** Üst ve alt bölgelerin mikrofona mesafesi benzer olabilir.
  Doğruluk düşükse bölgeleri birbirinden uzağa koy.
- **Kalibrasyon modunda klavyeye vurma** — tuş sesleri örnek olarak kaydedilir.
- **EN AZ GÜVEN** kaydırıcısı yanlış tetiklemeye karşı ilk savunma. Kısayolun
  yıkıcıysa (⌘W gibi) bunu yüksek tut.

## Doğrulama

```bash
.build/release/TapSpaces --selftest
```

FFT, bant hesabı, ses şiddeti bağımsızlığı, k-NN, leave-one-out, JSON round-trip
ve tuş biçimlendirmesini kontrol eder.

## Dosyalar

| Dosya | İş |
|---|---|
| `Features.swift` | Accelerate FFT + 56 boyutlu öznitelik çıkarma |
| `KNN.swift` | Sınıflandırıcı + leave-one-out çapraz doğrulama |
| `TapDetector.swift` | AVAudioEngine yakalama + onset algılama |
| `KeyAction.swift` | Tuş kodu modeli, CGEvent gönderme, klavye düzeni isimleri |
| `ShortcutCapture.swift` | CGEventTap ile kombinasyon kaydı (sistem tuşları dahil) |
| `AppState.swift` | Durum, kalıcılık, vuruş → kısayol bağlantısı |
| `ContentView.swift` | SwiftUI arayüz |
| `main.swift` | Menü çubuğu, pencere yönetimi |
| `SelfTest.swift` | Başsız doğrulama |
| `Toast.swift` | Ekran altı bildirim (Liquid Glass) |
| `icon/make-icon.swift` | Uygulama ikonunu çizer, `build.sh` çağırır |

## İkon

2×2 bölge ızgarası, biri yanıyor, oradan dalgalar yayılıyor — uygulamanın
yaptığı iş. `icon/make-icon.swift` CoreGraphics ile çiziyor, `build.sh` her
derlemede yeniden üretip `.icns`'e paketliyor.

Her boyut tek bir büyük görselden küçültülmüyor, kendi geometrisiyle ayrı
çiziliyor. 40px altında ızgara çizgileri ve dalgalar düşüyor; dört kare dolu
hale geliyor, çünkü 16px'te ince kontur gri bir lekeye dönüşüyor ama dolu
kareler ızgara olarak okunmaya devam ediyor.

Menü çubuğu ikonu aynı işaretin template hali (`main.swift` içinde çiziliyor),
açık/koyu menü çubuğunda macOS otomatik renklendiriyor.

Sadece ikonu yeniden üretmek için:

```bash
swift icon/make-icon.swift icon/AppIcon.iconset
iconutil -c icns icon/AppIcon.iconset -o icon/AppIcon.icns
```
