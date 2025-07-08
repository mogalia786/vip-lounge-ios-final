import os
import json
import requests
from datetime import datetime
from pathlib import Path

# Configuration
BRANDS = ["Apple", "Samsung", "Huawei", "Nokia", "Nova"]
RAPIDAPI_KEY = "YOUR_RAPIDAPI_KEY"  # Replace with your actual key
RAPIDAPI_HOST = "mobile-phone-specs-database.p.rapidapi.com"
BASE_DIR = Path(__file__).parent.parent
ASSETS_DIR = BASE_DIR / "assets"

# Ensure assets directory exists
ASSETS_DIR.mkdir(exist_ok=True)

def fetch_models(brand_name):
    """Fetch models for a specific brand from the API"""
    url = f"https://{RAPIDAPI_HOST}/gsm/get-models-by-brandname/{brand_name}"
    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPI_HOST
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error fetching models for {brand_name}: {e}")
        return []

def fetch_phone_details(model_id):
    """Fetch details for a specific phone model"""
    url = f"https://{RAPIDAPI_HOST}/gsm/get-specifications/{model_id}"
    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPI_HOST
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error fetching details for model {model_id}: {e}")
        return {}

def update_brands_file():
    """Create or update the brands JSON file"""
    brands_data = [
        {"brandValue": brand, "device_count": 0}
        for brand in BRANDS
    ]
    
    with open(ASSETS_DIR / "phone_brands.json", "w", encoding="utf-8") as f:
        json.dump(brands_data, f, indent=2)
    print("Updated phone_brands.json")

def update_models_files():
    """Update model files for each brand"""
    for brand in BRANDS:
        print(f"Updating models for {brand}...")
        models = fetch_models(brand)
        
        if not models:
            print(f"No models found for {brand}")
            continue
            
        # Save models list
        brand_id = brand.lower().replace(" ", "_")
        models_file = ASSETS_DIR / f"phone_models_{brand_id}.json"
        
        with open(models_file, "w", encoding="utf-8") as f:
            json.dump(models, f, indent=2)
        print(f"Saved {len(models)} models for {brand}")
        
        # Update details for each model (limit to top 5 to avoid too many API calls)
        for model in models[:5]:
            if 'device_name' in model and 'detail' in model:
                model_id = model['detail'].split('/')[-1]
                details = fetch_phone_details(model_id)
                
                if details:
                    details_file = ASSETS_DIR / f"phone_details_{model_id}.json"
                    with open(details_file, "w", encoding="utf-8") as f:
                        json.dump(details, f, indent=2)
                    print(f"  - Updated details for {model['device_name']}")

def main():
    print(f"Starting phone data update at {datetime.now()}")
    print("-" * 50)
    
    # Update brands file
    update_brands_file()
    
    # Update models and details
    update_models_files()
    
    print("-" * 50)
    print("Phone data update completed!")

if __name__ == "__main__":
    main()
