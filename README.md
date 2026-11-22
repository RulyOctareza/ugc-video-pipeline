# UGC Video Pipeline

Pipeline produksi video UGC 45 detik (9:16) dengan audio konsisten, produk terkunci, subtitle Indonesia burned-in — dirancang untuk produksi massal: satu folder per produk, sisanya otomatis.

![preview](previews/02-cta-product.jpg)

## Cara pakai (mode massal)

1. Buat folder `products/<slug-produk>/`
2. Isi `product.png` (gambar produk) + `brief.md` (template di `products/TEMPLATE/`)
3. Minta agent: *"bikin video untuk products/<slug>"*

Agent lalu menjalankan pipeline lengkap di bawah, termasuk QC visual.

## Konsep inti

Video UGC 45 detik tidak bisa dibagi ke beberapa generation tanpa risiko: **suara dan produk berubah antar generation**. Pipeline ini memaksimalkan konsistensi dengan dua aturan:

1. **Satu take untuk semua dialog.** Model video menyampling audio baru di tiap generation — timbre, aksen, bahkan gender bisa geser. Semua kalimat diucapkan dalam SATU generation (maks 30 detik di wan30), jadi voice konsisten by design.
2. **Satu gambar kanonik untuk semua generation.** Produk cepat drift kalau referensinya frame dari clip lain. Solusinya: bikin satu gambar referensi (orang + produk) via image-generation, review, lalu pakai sebagai referensi take.

Sisa 15 detik diisi CTA yang dirakit dari footage take yang sama (multi-segmen slow zoom + text card) — zero generation tambahan, zero drift.

## Alur produksi (yang dilakukan agent)

```
1. Review product.png secara visual
   -> tulis deskripsi product-lock (bentuk, tekstur, logo, aksen)
   -> susun naskah 45-50 kata: hook -> keluhan -> reveal -> masalah
      -> solusi -> impact, lalu beat review -> CTA

2. Gambar kanonik (1x per produk)
   ImageGen, input product.png
   Prompt: orang konsisten + product-lock + "do not redesign"
   -> contoh hasil: images/sandisk-creator-ref.png

3. Take utama 30 detik (SATU generation, berbayar)
   VideoGen wan30, reference_to_video, 1080x1920, 30s
   references = [gambar kanonik]
   Prompt wajib:
   - "ONE continuous handheld selfie-style take, no scene cuts"
   - "same person, identical face/hair/shirt"
   - "product must remain exactly identical — same shape, texture, logo"
   - dialog Bahasa Indonesia eksplisit per beat

4. QC visual frame dari take
   -> cari window b-roll CTA yang produknya paling jelas
     (hero close-up ~12s, produk terangkat ~21s, dst)

5. Render final 45 detik
   ./scripts/render_final.sh take.mp4 subs.ass out.mp4 '11.2:5,19.5:5,25:5' 30

6. QC otomatis + visual
   ./scripts/qc.sh out.mp4 2:top 12:bottom 33:bottom 41:bottom
   + lihat sendiri frame kunci: produk sesuai? orang konsisten? caption ter-render?
   -> kalau melenceng: retry take (maks 1-2x)
```

## Struktur repo

```
├── products/
│   └── TEMPLATE/brief.md          # template brief per produk
├── scripts/
│   ├── render_final.sh            # take + CTA multi-segmen + subtitle burn
│   └── qc.sh                      # probe + loudness + OCR caption
├── subtitles/
│   ├── sandisk_ugc_subs_v2.ass    # contoh timeline final 45s
│   └── sandisk_ugc_subs_v1.ass    # arsip versi 3-clip (timeline lama)
├── images/sandisk-creator-ref.png # contoh gambar kanonik
└── previews/                      # frame contoh hasil final
```

File video/media besar tidak masuk repo (batas GitHub 100 MB/file + bloat history). Simpan di luar repo, atau pakai Git LFS / Releases.

## Subtitle

Pakai format ASS (bukan SRT) supaya styling penuh:

- PlayRes 1080x1920, font Arial Black 68px bold
- Putih `&H00FFFFFF`, outline hitam 7px (tanpa shadow)
- `Alignment 2` + `MarginV 300` untuk cue bawah (aman dari UI TikTok); cue hook pakai `Alignment 8` + `MarginV 170` (atas)
- `\fad(80,60)` per cue, timing per-beat ~2.5-3 detik
- Kalau tempo bicara geser: edit timing ASS saja, tidak perlu re-render video

## Verifikasi

```bash
./scripts/qc.sh out.mp4 2:top 12:bottom 33:bottom 41:bottom
```

- probe: durasi, resolusi, stream audio ada
- loudness: mean > -30 dB, max > -20 dB (audio tidak kosong)
- OCR crop caption: teks keluar = caption benar-benar burned
- plus inspeksi visual frame kunci oleh agent (produk, konsistensi orang, framing)

## Limit tool

- VideoGen: 2-30 detik per clip, mode `text_to_video` / `first_frame_to_video` / `reference_to_video`
- Kuota kredit tidak bisa dicek dari sisi agent; kalau kena limit, request akan error
- Generation tidak bisa dibatalkan setelah submit — tes 1 take dulu, retry hanya saat QC gagal

## Catatan TTS (opsional, bukan jalur utama)

Suara bawaan model lebih hidup daripada TTS, jadi jalur utama tetap audio dari take. Cadangan kalau butuh VO terkontrol: `edge-tts` (`id-ID-ArdiNeural` male / `id-ID-GadisNeural` female) — perlu mesin dengan internet + python `edge-tts`. macOS built-in hanya punya voice Indonesia `Damayanti` (female).
