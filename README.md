<p align="center" style="margin-bottom: 0;">
  <img src="HuggingSnap/Assets.xcassets/AppIcon.appiconset/SmolVLM logo.png" alt="HuggingSnap Banner">
</p>
<h1 align="center" style="margin-top: 0;">HuggingSnap</h1>

HuggingSnap is an iOS app that lets users quickly learn more about the places and objects around them. Just point your camera to do things like have text translated, summarized; identify plants and animals; and more.

HuggingSnap runs [SmolVLM2](https://huggingface.co/collections/HuggingFaceTB/smolvlm2-smallest-video-lm-ever-67ab6b5e84bf8aaa60cb17c7), a compact open multimodal model that accepts arbitrary sequences of image, videos, and text inputs to produce text outputs. 

Designed for efficiency, SmolVLM can answer questions about images, describe visual content, create stories grounded on multiple images, or function as a pure language model without visual inputs. Its lightweight architecture makes it suitable for on-device applications while maintaining strong performance on multimodal tasks.

The repository makes use of a modified version of [mlx-swift-examples](https://github.com/cyrilzakka/mlx-swift-examples) for VLM support.

## How to run

- Install the [TestFligh beta](https://testflight.apple.com/join/c1MPaHDF). You need an iPhone running iOS 18.

Or, to build the app yourself:
- Clone the repository
- Open `HuggingSnap.xcodeproj` in Xcode
- Configure your API credentials:
  - Copy `HuggingSnap/APIConfig.template.swift` to `HuggingSnap/APIConfig.swift`
  - Replace the placeholder values with your actual Hugging Face API endpoint and API key
- Run the app on a physical device

You'll need to change the bundle identifier and developer team to run the app on your device.

## API Configuration

The app now uses a Hugging Face API for image analysis instead of running models locally. To use the app:

1. You'll need a Hugging Face API endpoint and key
2. Create the file `HuggingSnap/APIConfig.swift` based on the template
3. Add your API endpoint and key to the configuration file

The APIConfig.swift file is excluded from Git to prevent credentials from being committed.
