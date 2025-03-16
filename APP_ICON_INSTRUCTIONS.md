# App Icon Instructions

## Replacing the App Icon

1. Replace the file `HuggingSnap/Assets.xcassets/AppIcon.appiconset/SmolVLM logo.png` with a new heart-themed icon for SnapECG.

2. The icon should be a red heart on a white background or a heart ECG design in the same style as the current app design.

3. Icon requirements:
   - 1024x1024 pixels
   - PNG format
   - 72 DPI
   - sRGB color profile
   - No alpha/transparency

4. After replacing the icon file, rename it to "SnapECG logo.png" and update the reference in Contents.json to match the new filename.

5. You might need to run the following commands to update the app icon:
   ```bash
   cd /Users/papirobbi/Documents/GitHub/HuggingSnap
   mv HuggingSnap/Assets.xcassets/AppIcon.appiconset/SmolVLM\ logo.png HuggingSnap/Assets.xcassets/AppIcon.appiconset/SnapECG\ logo.png
   ```

6. Then edit `HuggingSnap/Assets.xcassets/AppIcon.appiconset/Contents.json` to update the filename reference.

## Icon Design Suggestions

Consider using:
- A red heart icon with an ECG trace across it
- A medical-themed heart symbol 
- A heart with an integrated waveform
- Clean design with minimal details for recognition at small sizes

The app icon should convey the app's purpose: ECG analysis with a focus on cardiac health.