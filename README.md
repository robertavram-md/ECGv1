<p align="center" style="margin-bottom: 0;">
  <img src="HuggingSnap/Assets.xcassets/AppIcon.appiconset/SmolVLM logo.png" alt="SnapECG Banner">
</p>
<h1 align="center" style="margin-top: 0;">SnapECG</h1>

SnapECG is an iOS app that allows users to analyze ECG images using Hugging Face's powerful vision-language model. Simply take a photo of an ECG or select one from your photo library, and the app will provide an interpretation.

SnapECG uses a specialized Hugging Face API for medical image understanding, providing accurate ECG analysis while keeping the app lightweight. 

The app utilizes a specialized ECG analysis model that can identify key cardiac patterns and abnormalities. It's designed for educational purposes and to provide a quick reference, though it should not replace professional medical evaluation.

## How to run

- Install the [TestFligh beta](https://testflight.apple.com/join/c1MPaHDF). You need an iPhone running iOS 18.

Or, to build the app yourself:
- Clone the repository
- Open the Xcode project in Xcode
- Configure your API credentials:
  - Copy `APIConfig.template.swift` to `APIConfig.swift`
  - Replace the placeholder values with your actual Hugging Face API endpoint and API key
- Run the app on a physical device

You'll need to change the bundle identifier and developer team to run the app on your device.

## API Configuration

The app uses a Hugging Face API for ECG image analysis. The default installation includes a pre-configured API key, so most users won't need to change anything.

If you need to use your own API key:

1. The API key is stored in `APIConfig.swift` (excluded from git)
2. This file is pre-configured with the default credentials
3. If you wish to use your own key, simply modify the `huggingFaceAPIKey` value

For developers:
- The actual API credentials are in `APIConfig.swift` (not tracked in git)
- A template version (`APIConfig.template.swift`) is included for reference
- The app validates API configuration at startup and provides warnings if not properly set up

## Medical Disclaimer

SnapECG is intended for educational purposes only. The app should not be used for diagnosis, treatment, or prevention of any disease or health condition. Always consult with a qualified healthcare provider for medical advice.
