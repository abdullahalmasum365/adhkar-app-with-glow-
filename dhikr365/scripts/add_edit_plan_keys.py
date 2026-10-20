import json
import os

i18n_dir = r"c:\Users\UNSTOPPABLE\Music\apps\Adhkar365 working\dhikr365\assets\i18n"

translations = {
    "en": {
        "edit_morning_plan": "Edit Morning Plan",
        "edit_evening_plan": "Edit Evening Plan",
        "edit_protection_plan": "Edit Protection Plan",
        "edit_focus_plan": "Edit Focus Plan",
        "edit_plan_info": "Modify the standard set of supplications to fit your time.",
        "edit_plan_sequence": "SEQUENCE & TOGGLES",
        "edit_plan_reorder_hint": "Hold handle to reorder",
        "save_morning_plan": "Save Morning Plan",
        "save_evening_plan": "Save Evening Plan",
        "save_plan": "Save Plan",
        "reset_to_default": "Reset to Default",
        "plan_saved": "Plan Saved!"
    },
    "bn": {
        "edit_morning_plan": "সকালের পরিকল্পনা এডিট করুন",
        "edit_evening_plan": "সন্ধ্যার পরিকল্পনা এডিট করুন",
        "edit_protection_plan": "সুরক্ষার পরিকল্পনা এডিট করুন",
        "edit_focus_plan": "ফোকাস পরিকল্পনা এডিট করুন",
        "edit_plan_info": "আপনার সময় অনুযায়ী দোয়ার তালিকা পরিবর্তন ও সাজিয়ে নিন।",
        "edit_plan_sequence": "ধারাবাহিকতা ও সক্রিয়করণ",
        "edit_plan_reorder_hint": "ক্রম পরিবর্তন করতে হ্যান্ডেলে চেপে ধরে টানুন",
        "save_morning_plan": "সকালের পরিকল্পনা সংরক্ষণ করুন",
        "save_evening_plan": "সন্ধ্যার পরিকল্পনা সংরক্ষণ করুন",
        "save_plan": "পরিকল্পনা সংরক্ষণ করুন",
        "reset_to_default": "ডিফল্টে রিসেট করুন",
        "plan_saved": "পরিকল্পনা সংরক্ষিত হয়েছে!"
    },
    "ar": {
        "edit_morning_plan": "تعديل أذكار الصباح",
        "edit_evening_plan": "تعديل أذكار المساء",
        "edit_protection_plan": "تعديل أذكار الحفظ",
        "edit_focus_plan": "تعديل أذكار التركيز",
        "edit_plan_info": "قم بتعديل قائمة الأذكار لتناسب وقتك وتحديد ترتيبها.",
        "edit_plan_sequence": "الترتيب والتفعيل",
        "edit_plan_reorder_hint": "اضغط مع السحب لتغيير الترتيب",
        "save_morning_plan": "حفظ أذكار الصباح",
        "save_evening_plan": "حفظ أذكار المساء",
        "save_plan": "حفظ الخطة",
        "reset_to_default": "إعادة تعيين إلى الافتراضي",
        "plan_saved": "تم حفظ الخطة!"
    },
    "de": {
        "edit_morning_plan": "Morgenplan bearbeiten",
        "edit_evening_plan": "Abendplan bearbeiten",
        "edit_protection_plan": "Schutzplan bearbeiten",
        "edit_focus_plan": "Fokusplan bearbeiten",
        "edit_plan_info": "Passe die Liste der Bittgebete an deine Zeit an.",
        "edit_plan_sequence": "REIHENFOLGE & AUSWAHL",
        "edit_plan_reorder_hint": "Ziehen zum Neuanordnen",
        "save_morning_plan": "Morgenplan speichern",
        "save_evening_plan": "Abendplan speichern",
        "save_plan": "Plan speichern",
        "reset_to_default": "Auf Standard zurücksetzen",
        "plan_saved": "Plan gespeichert!"
    },
    "es": {
        "edit_morning_plan": "Editar plan de la mañana",
        "edit_evening_plan": "Editar plan de la tarde",
        "edit_protection_plan": "Editar plan de protección",
        "edit_focus_plan": "Editar plan de enfoque",
        "edit_plan_info": "Modifica el conjunto estándar de súplicas para adaptarlo a tu tiempo.",
        "edit_plan_sequence": "SECUENCIA Y SELECCIÓN",
        "edit_plan_reorder_hint": "Mantén presionado para reordenar",
        "save_morning_plan": "Guardar plan de la mañana",
        "save_evening_plan": "Guardar plan de la tarde",
        "save_plan": "Guardar plan",
        "reset_to_default": "Restablecer por defecto",
        "plan_saved": "¡Plan guardado!"
    },
    "fr": {
        "edit_morning_plan": "Modifier le plan du matin",
        "edit_evening_plan": "Modifier le plan du soir",
        "edit_protection_plan": "Modifier le plan de protection",
        "edit_focus_plan": "Modifier le plan de concentration",
        "edit_plan_info": "Modifiez l'ensemble des invocations pour l'adapter à votre temps.",
        "edit_plan_sequence": "SÉQUENCE & ACTIVATION",
        "edit_plan_reorder_hint": "Maintenez la poignée pour réorganiser",
        "save_morning_plan": "Enregistrer le plan du matin",
        "save_evening_plan": "Enregistrer le plan du soir",
        "save_plan": "Enregistrer le plan",
        "reset_to_default": "Réinitialiser par défaut",
        "plan_saved": "Plan enregistré !"
    },
    "hi": {
        "edit_morning_plan": "सुबह की योजना संपादित करें",
        "edit_evening_plan": "शाम की योजना संपादित करें",
        "edit_protection_plan": "सुरक्षा योजना संपादित करें",
        "edit_focus_plan": "फोकस योजना संपादित करें",
        "edit_plan_info": "अपने समय के अनुसार दुआओं की सूची को अनुकूलित करें।",
        "edit_plan_sequence": "क्रम और टॉगल",
        "edit_plan_reorder_hint": "क्रम बदलने के लिए हैंडल दबाकर खींचें",
        "save_morning_plan": "सुबह की योजना सहेजें",
        "save_evening_plan": "शाम की योजना सहेजें",
        "save_plan": "योजना सहेजें",
        "reset_to_default": "डिफ़ॉल्ट पर रीसेट करें",
        "plan_saved": "योजना सहेजी गई!"
    },
    "id": {
        "edit_morning_plan": "Edit Rencana Pagi",
        "edit_evening_plan": "Edit Rencana Petang",
        "edit_protection_plan": "Edit Rencana Perlindungan",
        "edit_focus_plan": "Edit Rencana Fokus",
        "edit_plan_info": "Sesuaikan daftar doa standar agar sesuai dengan waktu Anda.",
        "edit_plan_sequence": "URUTAN & AKTIVASI",
        "edit_plan_reorder_hint": "Tahan gagang untuk mengubah urutan",
        "save_morning_plan": "Simpan Rencana Pagi",
        "save_evening_plan": "Simpan Rencana Petang",
        "save_plan": "Simpan Rencana",
        "reset_to_default": "Atur Ulang ke Default",
        "plan_saved": "Rencana Tersimpan!"
    },
    "it": {
        "edit_morning_plan": "Modifica piano del mattino",
        "edit_evening_plan": "Modifica piano della sera",
        "edit_protection_plan": "Modifica piano di protezione",
        "edit_focus_plan": "Modifica piano di concentrazione",
        "edit_plan_info": "Modifica l'elenco delle suppliche per adattarlo al tuo tempo.",
        "edit_plan_sequence": "SEQUENZA E ATTIVAZIONE",
        "edit_plan_reorder_hint": "Tieni premuto per riordinare",
        "save_morning_plan": "Salva piano del mattino",
        "save_evening_plan": "Salva piano della sera",
        "save_plan": "Salva piano",
        "reset_to_default": "Ripristina predefiniti",
        "plan_saved": "Piano salvato!"
    },
    "ja": {
        "edit_morning_plan": "朝のプランを編集",
        "edit_evening_plan": "夕方のプランを編集",
        "edit_protection_plan": "保護プランを編集",
        "edit_focus_plan": "集中プランを編集",
        "edit_plan_info": "あなたの時間に合わせて祈りのリストを調整してください。",
        "edit_plan_sequence": "順序と切り替え",
        "edit_plan_reorder_hint": "長押しして並べ替え",
        "save_morning_plan": "朝のプランを保存",
        "save_evening_plan": "夕方のプランを保存",
        "save_plan": "プランを保存",
        "reset_to_default": "デフォルトにリセット",
        "plan_saved": "プランが保存されました！"
    },
    "ms": {
        "edit_morning_plan": "Edit Pelan Pagi",
        "edit_evening_plan": "Edit Pelan Petang",
        "edit_protection_plan": "Edit Pelan Perlindungan",
        "edit_focus_plan": "Edit Pelan Fokus",
        "edit_plan_info": "Ubah suai senarai doa standard mengikut masa anda.",
        "edit_plan_sequence": "TURUTAN & PENGAKTIFAN",
        "edit_plan_reorder_hint": "Tahan pemegang untuk menyusun semula",
        "save_morning_plan": "Simpan Pelan Pagi",
        "save_evening_plan": "Simpan Pelan Petang",
        "save_plan": "Simpan Pelan",
        "reset_to_default": "Tetapkan Semula ke Lalai",
        "plan_saved": "Pelan Disimpan!"
    },
    "nl": {
        "edit_morning_plan": "Ochtendplan bewerken",
        "edit_evening_plan": "Avondplan bewerken",
        "edit_protection_plan": "Beschermingsplan bewerken",
        "edit_focus_plan": "Focusplan bewerken",
        "edit_plan_info": "Pas de lijst met smeekbeden aan aan uw tijd.",
        "edit_plan_sequence": "VOLGORDE & ACTIVERING",
        "edit_plan_reorder_hint": "Houd vast om te herschikken",
        "save_morning_plan": "Ochtendplan opslaan",
        "save_evening_plan": "Avondplan opslaan",
        "save_plan": "Plan opslaan",
        "reset_to_default": "Herstellen naar standaard",
        "plan_saved": "Plan opgeslagen!"
    },
    "pt": {
        "edit_morning_plan": "Editar plano da manhã",
        "edit_evening_plan": "Editar plano da tarde",
        "edit_protection_plan": "Editar plano de proteção",
        "edit_focus_plan": "Editar plano de foco",
        "edit_plan_info": "Modifique o conjunto padrão de súplicas para se adequar ao seu tempo.",
        "edit_plan_sequence": "SEQUÊNCIA E SELEÇÃO",
        "edit_plan_reorder_hint": "Segure para reordenar",
        "save_morning_plan": "Salvar plano da manhã",
        "save_evening_plan": "Salvar plano da tarde",
        "save_plan": "Salvar plano",
        "reset_to_default": "Restaurar padrão",
        "plan_saved": "Plano salvo!"
    },
    "ru": {
        "edit_morning_plan": "Изменить утренний план",
        "edit_evening_plan": "Изменить вечерний план",
        "edit_protection_plan": "Изменить план защиты",
        "edit_focus_plan": "Изменить план фокуса",
        "edit_plan_info": "Настройте список мольб под своё время.",
        "edit_plan_sequence": "ПОРЯДОК И ВКЛЮЧЕНИЕ",
        "edit_plan_reorder_hint": "Удерживайте значок для перемещения",
        "save_morning_plan": "Сохранить утренний план",
        "save_evening_plan": "Сохранить вечерний план",
        "save_plan": "Сохранить план",
        "reset_to_default": "Сбросить по умолчанию",
        "plan_saved": "План сохранён!"
    },
    "ta": {
        "edit_morning_plan": "காலை திட்டத்தை திருத்தவும்",
        "edit_evening_plan": "மாலை திட்டத்தை திருத்தவும்",
        "edit_protection_plan": "பாதுகாப்பு திட்டத்தை திருத்தவும்",
        "edit_focus_plan": "கவன திட்டத்தை திருத்தவும்",
        "edit_plan_info": "உங்கள் நேரத்திற்கு ஏற்ப துஆக்களின் பட்டியலை மாற்றியமைக்கவும்.",
        "edit_plan_sequence": "வரிசை & தேர்வு",
        "edit_plan_reorder_hint": "வரிசையை மாற்ற பிடித்து இழுக்கவும்",
        "save_morning_plan": "காலை திட்டத்தை சேமிக்கவும்",
        "save_evening_plan": "மாலை திட்டத்தை சேமிக்கவும்",
        "save_plan": "திட்டத்தை சேமிக்கவும்",
        "reset_to_default": "இயல்புநிலைக்கு மீட்டமைக்கவும்",
        "plan_saved": "திட்டம் சேமிக்கப்பட்டது!"
    },
    "th": {
        "edit_morning_plan": "แก้ไขแผนตอนเช้า",
        "edit_evening_plan": "แก้ไขแผนตอนเย็น",
        "edit_protection_plan": "แก้ไขแผนการปกป้อง",
        "edit_focus_plan": "แก้ไขแผนโฟกัส",
        "edit_plan_info": "ปรับเปลี่ยนรายการดุอาอ์ให้เหมาะกับเวลาของคุณ",
        "edit_plan_sequence": "ลำดับและการเปิดปิด",
        "edit_plan_reorder_hint": "กดค้างเพื่อจัดลำดับใหม่",
        "save_morning_plan": "บันทึกแผนตอนเช้า",
        "save_evening_plan": "บันทึกแผนตอนเย็น",
        "save_plan": "บันทึกแผน",
        "reset_to_default": "รีเซ็ตเป็นค่าเริ่มต้น",
        "plan_saved": "บันทึกแผนแล้ว!"
    },
    "tr": {
        "edit_morning_plan": "Sabah Planını Düzenle",
        "edit_evening_plan": "Akşam Planını Düzenle",
        "edit_protection_plan": "Korunma Planını Düzenle",
        "edit_focus_plan": "Odak Planını Düzenle",
        "edit_plan_info": "Dualar listesini zamanınıza uyacak şekilde düzenleyin.",
        "edit_plan_sequence": "SIRA VE ETKİNLEŞTİRME",
        "edit_plan_reorder_hint": "Yeniden sıralamak için basılı tutun",
        "save_morning_plan": "Sabah Planını Kaydet",
        "save_evening_plan": "Akşam Planını Kaydet",
        "save_plan": "Planı Kaydet",
        "reset_to_default": "Varsayılana Sıfırla",
        "plan_saved": "Plan kaydedildi!"
    },
    "ur": {
        "edit_morning_plan": "صبح کا منصوبہ تبدیل کریں",
        "edit_evening_plan": "شام کا منصوبہ تبدیل کریں",
        "edit_protection_plan": "حفاظت کا منصوبہ تبدیل کریں",
        "edit_focus_plan": "توجہ کا منصوبہ تبدیل کریں",
        "edit_plan_info": "اپنے وقت کے مطابق دعاؤں کی فہرست میں ردوبدل کریں۔",
        "edit_plan_sequence": "ترتیب اور فعال کاری",
        "edit_plan_reorder_hint": "ترتیب بدلنے کے لیے پکڑ کر کھینچیں",
        "save_morning_plan": "صبح کا منصوبہ محفوظ کریں",
        "save_evening_plan": "شام کا منصوبہ محفوظ کریں",
        "save_plan": "منصوبہ محفوظ کریں",
        "reset_to_default": "پہلے جیسا کریں",
        "plan_saved": "منصوبہ محفوظ ہوگیا!"
    },
    "zh": {
        "edit_morning_plan": "编辑早晨计划",
        "edit_evening_plan": "编辑傍晚计划",
        "edit_protection_plan": "编辑保护计划",
        "edit_focus_plan": "编辑专注计划",
        "edit_plan_info": "根据您的时间调整赞念列表。",
        "edit_plan_sequence": "顺序与开关",
        "edit_plan_reorder_hint": "按住手柄以重新排序",
        "save_morning_plan": "保存早晨计划",
        "save_evening_plan": "保存傍晚计划",
        "save_plan": "保存计划",
        "reset_to_default": "恢复默认",
        "plan_saved": "计划已保存！"
    }
}

for lang, new_keys in translations.items():
    file_path = os.path.join(i18n_dir, f"{lang}.json")
    if not os.path.exists(file_path):
        print(f"Skipping {file_path}, does not exist")
        continue
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    for k, v in new_keys.items():
        data[k] = v
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Updated {lang}.json with {len(new_keys)} keys")

print("All done!")
