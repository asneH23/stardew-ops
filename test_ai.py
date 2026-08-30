import os, json
import google.generativeai as genai

# Testa om nyckeln funkar live
key = os.getenv("GEMINI_API_KEY", "")
if not key:
    print("❌ Ingen lokalt satt nyckel.")
else:
    genai.configure(api_key=key)
    model = genai.GenerativeModel('gemini-1.5-flash')
    try:
        resp = model.generate_content("Säg hej!")
        print("✅ Gemini API funkar:", resp.text.strip())
    except Exception as e:
        print("❌ Gemini Fel:", e)
