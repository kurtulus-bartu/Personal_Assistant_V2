# HealthKit Kurulum Rehberi

Bu uygulama Apple Health verilerini okumak ve yazmak için HealthKit framework'ünü kullanmaktadır.

## Gerekli Adımlar

### 1. Xcode Proje Ayarları

Xcode'da projenizin hedefini (target) seçin:

1. **Signing & Capabilities** sekmesine gidin
2. **+ Capability** butonuna tıklayın
3. **HealthKit** seçeneğini ekleyin
4. **Clinical Health Records** opsiyonunu devre dışı bırakın (gerekli değilse)

### 2. Info.plist İzinleri

Aşağıdaki anahtarları Info.plist dosyanıza ekleyin:

```xml
<!-- HealthKit izni için açıklama -->
<key>NSHealthShareUsageDescription</key>
<string>Uyku, adım sayısı, kalori ve kilo verilerinizi görüntülemek ve analiz etmek için Apple Health verilerinize erişmek istiyoruz.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Yemek ve kalori verilerinizi Apple Health'e kaydetmek için izin gerekiyor.</string>
```

### 3. Okunan Veri Türleri

Uygulama aşağıdaki verileri Apple Health'ten okur:

#### Aktivite Verileri
- **Adım Sayısı** (`HKQuantityTypeIdentifierStepCount`)
- **Aktif Kalori** (`HKQuantityTypeIdentifierActiveEnergyBurned`)
- **Egzersiz Süresi** (`HKQuantityTypeIdentifierAppleExerciseTime`)

#### Beslenme Verileri
- **Alınan Kalori** (`HKQuantityTypeIdentifierDietaryEnergyConsumed`)

#### Uyku Verileri
- **Uyku Analizi** (`HKCategoryTypeIdentifierSleepAnalysis`)

#### Vücut Ölçümleri
- **Kilo** (`HKQuantityTypeIdentifierBodyMass`)
- **Yağ Oranı** (`HKQuantityTypeIdentifierBodyFatPercentage`)
- **Kas Kütlesi** (`HKQuantityTypeIdentifierLeanBodyMass`)
- **BMI** (`HKQuantityTypeIdentifierBodyMassIndex`)

### 4. Yazılan Veri Türleri

Uygulama gelecekte aşağıdaki verileri Apple Health'e yazabilir:

- **Alınan Kalori** (`HKQuantityTypeIdentifierDietaryEnergyConsumed`)

## Kullanım

Uygulama ilk açıldığında otomatik olarak HealthKit izinlerini isteyecektir. Kullanıcı izin verirse:

1. **Health** sekmesinde:
   - Uyku verileri
   - Adım sayısı ve hareket verileri
   - Kalori verileri (yakılan ve alınan)
   - Tartı verileri (kilo, yağ oranı, kas kütlesi, BMI)

2. **Fitness** sekmesinde:
   - Egzersiz verileri
   - Aktif dakikalar

Bu veriler otomatik olarak Apple Health uygulamasından çekilir ve görüntülenir.

## Fallback

Eğer kullanıcı HealthKit izinlerini vermezse, uygulama örnek verilerle çalışmaya devam eder.

## Not

- Bu entegrasyon sadece iOS cihazlarda çalışır
- Apple Watch verisi varsa, otomatik olarak senkronize edilir
- Veriler gerçek zamanlı olarak güncellenir
