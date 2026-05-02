# qanat

> القناة - الممر اللي بينقل المياه تحت الصحرا.

تشغل التحميل والميديا على VPS سريع، وبتسحبها على وصلتك البطيئة.
متعمل لاتصالات الإنترنت في مصر.

English: [README.md](./README.md)

## المكونات

- **aria2-pro** + **ariang** - تحميل multi-connection (http + torrent)
- **metube** - yt-dlp بواجهة ويب (يوتيوب + 1000 موقع تاني)
- **jellyfin** - بث فيديو
- **navidrome** - بث موسيقى (اختياري)
- **caddy** - reverse proxy بـ TLS تلقائي + Basic Auth
- **cloudflared** - tunnel من غير ما تفتح بورتات (اختياري)
- **warp** - socks5 لتخطي حظر يوتيوب لـ IPs الـ datacenter (اختياري)

## ليه

لو اتصالك بيوتيوب أو ميجا سيء، بس وصلتك بـ VPS واحد في أوروبا كويسة،
خلي الـ VPS يعمل التحميل مرة واحدة على وصلته الجيجابت، وبعدين انت اسحب
الملف منه. iso حجمه 4 جيجا اللي بياخد ساعات بينزل في ثواني عند الـ VPS،
ومن الـ VPS بتلاقي peer قريب وثابت تسحب منه بسرعة.

```
الإنترنت المصري  <-- tunnel -->  VPS  <-- جيجابت -->  الإنترنت
                                  |
                             aria2 / yt-dlp
                                  |
                             jellyfin / sshfs
```

## التشغيل السريع

```bash
git clone https://github.com/Mostafa-M-Hussein/qanat.git
cd qanat
./setup.sh
$EDITOR .env

# توليد hash للباسورد
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-pw'

# DNS:
#   jellyfin.example.com  A  <vps-ip>
#   aria.example.com      A  <vps-ip>
#   metube.example.com    A  <vps-ip>

# الجدار الناري: افتح 80, 443, 443/udp, 6888

docker compose up -d
```

إضافات اختيارية:

```bash
docker compose --profile music up -d     # navidrome
docker compose --profile warp up -d      # warp (تخطي حظر يوتيوب)
docker compose --profile tunnel up -d    # cloudflare tunnel
```

## ٣ طرق للوصول

كل الخدمات ما عدا caddy والـ bt port متربوطة على `127.0.0.1`. توصلها بـ:

1. **caddy** - عام، TLS، Basic Auth
2. **SSH tunnel** - خاص، من غير سطح هجوم عام:
   ```bash
   ssh -L 6880:localhost:6880 -L 8081:localhost:8081 -L 8096:localhost:8096 user@vps
   ```
3. **cloudflare tunnel** - `--profile tunnel`، من غير ما تفتح أي بورت

## ليه metube بيمر على warp

يوتيوب بيحظر أغلب IPs الـ datacenter:

```
ERROR: [youtube] xxxx: Sign in to confirm you're not a bot.
```

`--profile warp` بيشغل warp socks5 مجاني على `warp:1080`. الـ
`METUBE_YTDL_OPTIONS` الافتراضي بيمر على الـ proxy ده.

## مشاركة مع الأصحاب

الـ compose ده ستاك واحد لمستخدم واحد. لو عايز تشارك، شوف
[docs/per-user-isolation.md](./docs/per-user-isolation.md). الباختصار:

- إديله يوزر jellyfin بس (مفيش shell، مفيش تحميل)، أو
- إديله SSH user محصور في port-forwarding (مفيش shell، يقدر يعمل
  tunnel للبورتات الـ loopback)، أو
- إديله container كامل بـ Incus/LXC بحدود ديسك وباندوويث

متديش حد shell حقيقي على السيرفر.

## الأمان

- [ ] `ARIA2_RPC_SECRET` عشوائي (setup.sh بيعمل ده)
- [ ] `BASIC_AUTH_HASH` متحط
- [ ] باسورد admin بتاع jellyfin متحط من أول تشغيل
- [ ] الجدار الناري: 80, 443, bt port بس
- [ ] crowdsec أو fail2ban على لوجات caddy
- [ ] backup لـ `aria2-config/`, `jellyfin/config/`, `caddy/data/`

## الترخيص

MIT - شوف [LICENSE](./LICENSE).
