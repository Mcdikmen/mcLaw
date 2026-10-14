# mcLaw — Adalet (DOJ) Yönetim Sistemi

FiveM için uçtan uca adalet sistemi: sevk raporu, soruşturma, iddianame, duruşma, karar, dilekçe ve hükmün infazı.
County RP için **QBCore** sürümüdür (arayüz ve metinler tamamen Türkçe). Orijinal Qbox sürümü deponun ilk commit'lerindedir.

## Özellikler

- **Sevk raporu (polis):** şüpheli, suçlar, olay anlatımı, kanıt. Şüpheli suçlamayı kabul edebilir veya itiraz edebilir.
- **Soruşturma / dosya açma:** savcı, hakim ve avukat dosya açar; hakim onayı akışı.
- **İddianame ve duruşma:** yüz yüze veya yazılı yargılama.
- **Karar:** mahkûmiyet, beraat, davanın düşmesi; suç başına ceza değişikliği; beraat tazminatı.
- **Dilekçe:** avukat → savcılık (ceza) veya hakim (hukuk).
- **Hükmün infazı (qb-prison):** karar kesinleşince kimse ışınlanmaz. Hüküm "infaz bekliyor" olur; görevdeki bir polis hükümlüyü
  hapishane girişine götürüp `/hapisteslim` yazar. Hapis qb-prison'a, MDT durumu codem-mdt'ye, para cezası codem-billing faturasına gider.
  Bekleyen hükümler `/hukumler` ile listelenir.
- **Suç listesi:** `shared/config.lua` içindeki Türkçe liste + codem-mdt'nin `mmdt_fines` tablosu (otomatik birleştirilir).
- **Discord webhook:** dosya açıldı, karar verildi vb. (URL `config.secret.lua` içinde, depoya girmez).

## Roller (tek `doj` işi, rütbeye göre)

| Rütbe (grade) | Rol |
|---|---|
| 10-11 | avukat |
| 12-13 | savcı |
| 14-15 | hakim |
| 16 (Başsavcı) | savcı |

Eşleşme `Config.Doj.roles` içindedir. Polis rolü `police` işidir.

## Bağımlılıklar

`qb-core`, `ox_lib`, `oxmysql` — isteğe bağlı: `qb-prison`, `qb-policejob`, `codem-mdt`, `codem-billing`.

## Kurulum

1. `install.sql` dosyasını veritabanında çalıştırın (tablolar `mclaw_*`, hepsi `IF NOT EXISTS`).
2. `config.secret.example.lua` dosyasını `config.secret.lua` olarak kopyalayın ve webhook URL'sini yazın.
3. `server.cfg` içinde `ensure mcLaw` (klasör `[other]` gibi bir gruptaysa ayrıca gerekmez).
4. `qb-core/shared/jobs.lua` içinde `doj` işi tanımlı olmalı (grade 10-16).

## Komutlar

`/mclaw` (panel), `/mclaw_report` ve `/referral` (sevk raporu), `/hukumler` (polis: bekleyen hükümler),
`/hapisteslim` (polis: hükümlüyü hapishane girişinde teslim et).

## Bilinen eksikler

- Tutuklama emri sekmesi henüz boş; codem-mdt'nin tutuklama emri için dışa açık bir fonksiyonu yok.
- Para cezaları ve süreler yer tutucudur (ekonomi kalibrasyonuna bağlı).
- Vekâletname ve müvekkil sekmeleri yapım aşamasında.

## Lisans

MIT — bkz. [LICENSE](LICENSE). © 2026 Mcdikmen.
