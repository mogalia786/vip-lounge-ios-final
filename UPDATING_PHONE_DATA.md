# Updating Phone Data

This document explains how to update the phone brands and models data in the app.

## Current Implementation

The app uses a local JSON file (`assets/data/phone_data.json`) to store phone brands and models. This provides offline functionality and doesn't require any API keys.

## How to Update Phone Data

### Option 1: Manual Update (Recommended)

1. Open `assets/data/phone_data.json` in a text editor
2. The file has this structure:
   ```json
   {
     "brands": [
       {"id": "apple", "name": "Apple"},
       ...
     ],
     "models": {
       "apple": [
         {"id": "iphone-15", "name": "iPhone 15"},
         ...
       ]
     }
   }
   ```
3. To add a new brand:
   - Add a new object to the `brands` array
   - Add a new entry to the `models` object with the brand ID as the key

4. To add new models to an existing brand:
   - Find the brand in the `models` object
   - Add new model objects to the array

### Option 2: Switch Back to API (Future Use)

If you want to switch back to using the RapidAPI in the future:

1. Get a RapidAPI key from https://rapidapi.com/azharxes/api/mobile-phones2
2. Create or update `.env` file in the project root:
   ```
   RAPID_API_KEY=your_api_key_here
   ```
3. Update `phone_api_client.dart` to use the API instead of local data

## Best Practices

- Keep the JSON file well-formatted
- Use consistent naming conventions for IDs (lowercase with hyphens)
- Update the data with each major app release
- Test the help feature after making changes

## Adding More Data

You can expand the JSON structure to include more phone details like:
- Release year
- Image URLs
- Specifications
- Common issues/solutions
