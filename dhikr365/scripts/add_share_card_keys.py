import json
import os

keys_data = {
    "en": {"share_as_image": "Share as Image", "generating_card": "Generating card…", "card_ready": "Card ready to share!"},
    "bn": {"share_as_image": "ছবি হিসেবে শেয়ার করুন", "generating_card": "কার্ড তৈরি করা হচ্ছে…", "card_ready": "কার্ড প্রস্তুত!"},
    "ar": {"share_as_image": "مشاركة كصورة", "generating_card": "جاري إنشاء البطاقة…", "card_ready": "البطاقة جاهزة للمشاركة!"},
    "ur": {"share_as_image": "تصویر کے طور پر شیئر کریں", "generating_card": "کارڈ بنایا جا رہا ہے…", "card_ready": "کارڈ شیئر کرنے کے لیے تیار ہے!"},
    "id": {"share_as_image": "Bagikan sebagai Gambar", "generating_card": "Membuat kartu…", "card_ready": "Kartu siap dibagikan!"},
    "tr": {"share_as_image": "Görsel Olarak Paylaş", "generating_card": "Kart oluşturuluyor…", "card_ready": "Kart paylaşıma hazır!"},
    "ms": {"share_as_image": "Kongsi sebagai Imej", "generating_card": "Menjana kad…", "card_ready": "Kad sedia dikongsi!"},
    "fr": {"share_as_image": "Partager comme image", "generating_card": "Génération de la carte…", "card_ready": "Carte prête à partager !"},
    "es": {"share_as_image": "Compartir como imagen", "generating_card": "Generando tarjeta…", "card_ready": "¡Tarjeta lista para compartir!"},
    "de": {"share_as_image": "Als Bild teilen", "generating_card": "Karte wird erstellt…", "card_ready": "Karte bereit zum Teilen!"},
    "hi": {"share_as_image": "छवि के रूप में साझा करें", "generating_card": "कार्ड बनाया जा रहा है…", "card_ready": "कार्ड साझा करने के लिए तैयार है!"},
    "ru": {"share_as_image": "Поделиться как изображением", "generating_card": "Создание карточки…", "card_ready": "Карточка готова к отправке!"},
    "pt": {"share_as_image": "Compartilhar como imagem", "generating_card": "Gerando cartão…", "card_ready": "Cartão pronto para compartilhar!"},
    "it": {"share_as_image": "Condividi come immagine", "generating_card": "Generazione della scheda…", "card_ready": "Scheda pronta per la condivisione!"},
    "nl": {"share_as_image": "Delen als afbeelding", "generating_card": "Kaart genereren…", "card_ready": "Kaart klaar om te delen!"},
    "ja": {"share_as_image": "画像として共有", "generating_card": "カードを作成中…", "card_ready": "共有の準備ができました！"},
    "zh": {"share_as_image": "以图片形式分享", "generating_card": "正在生成卡片…", "card_ready": "卡片已生成，可分享！"},
    "ta": {"share_as_image": "படமாக பகிரவும்", "generating_card": "அட்டை உருவாக்கப்படுகிறது…", "card_ready": "பகிர அட்டை தயார்!"},
    "th": {"share_as_image": "แชร์เป็นรูปภาพ", "generating_card": "กำลังสร้างการ์ด…", "card_ready": "การ์ดพร้อมแชร์แล้ว!"}
}

i18n_dir = "assets/i18n"
for code, keys in keys_data.items():
    path = os.path.join(i18n_dir, f"{code}.json")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for k, v in keys.items():
            data[k] = v
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"Updated {code}.json with share card keys.")
