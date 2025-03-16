//
//  ControlView.swift
//  SnapECG
//
//  Created by Cyril Zakka on 2/18/25.
//

import Foundation
import SwiftUI
import PhotosUI

struct ControlView: View {
    // SORRY THIS IS MESSY. Should clean it up someday when we know what features should be added.
    
    @EnvironmentObject var model: ContentViewModel
    
    // Bindings
    @Binding var selectedItem: PhotosPickerItem?
    
    @State private var isProcessing = false
    
    // Main button
    @Binding var isCaptured: Bool
    @State private var scaleDown: Bool = false
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0.3
    
    @Environment(VLMEvaluator.self) private var llm
    @Binding var loadState: LoadState
    
    // Alt buttons
    @State private var showInputView: Bool = false
    @State private var isAudioMode: Bool = false
    @State private var textFieldText = ""

    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                .clear,
                .white.opacity(opacity+0.1),
                .clear,
                .white.opacity(opacity),
                .clear,
                .white.opacity(opacity+0.1),
            ]),
            center: .center,
            startAngle: .degrees(270),
            endAngle: .degrees(0)
        )
    }
    
    var body: some View {
        
        if showInputView {
            InputView(isTextMode: $showInputView, isAudioMode: $isAudioMode, textFieldText: $textFieldText) { textPrompt in
                llm.customUserInput = textPrompt
                textFieldText = ""
                Task {
                    if case .loadedImage(let uIImage) = loadState {
                        let ciImage = CIImage(image: uIImage)
                        await llm.generate(image: ciImage ?? CIImage(), videoURL: nil)
                    }
                    if case .loadedMovie(let video) = loadState { await llm.generate(image: nil, videoURL: video.url) }
                }
            }
        } else {
            VStack(alignment: .center, spacing: 20) {
                
                if isCaptured {
                    HStack(spacing: 20) {
                        if case .loadedImage(let uIImage) = loadState {
                            Button {
                                // ECG Interpretation
                                llm.customUserInput = ""
                                Task {
                                    // Image is already rotated at capture time
                                    let ciImage = CIImage(image: uIImage)
                                    await llm.generate(image: ciImage ?? CIImage(), videoURL: nil)
                                }
                                
                            } label: {
                                Label("ECG Interpretation", systemImage: "waveform.path.ecg")
                                    .foregroundStyle(.white)
                                    .fontWeight(.semibold)
                                    .font(.footnote)
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 12)
                                    .background {
                                        Capsule()
                                            .fill(.ultraThickMaterial)
                                    }
                            }
                            .transition(.blurReplace.combined(with: .scale))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Bottom control buttons: ECG interpretation, capture/clear, coronary check
                HStack {
                    if isCaptured {
                        Button {
                            // ECG Interpretation using the side button
                            if case .loadedImage(let uIImage) = loadState {
                                llm.customUserInput = ""
                                Task {
                                    // Image is already rotated at capture time
                                    let ciImage = CIImage(image: uIImage)
                                    await llm.generate(image: ciImage ?? CIImage(), videoURL: nil)
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    } else {
                        PhotosPicker(selection: $selectedItem,
                                     matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "photo.fill.on.rectangle.fill")
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    
                    
                    Spacer()
                    
                    
                    
                    // Capture button which serves as photo capture and video recording
                    ZStack {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 20)
                            TransparentBlurView(removeAllFilters: true)
                                .blur(radius: 9, opaque: true)
                                .background(.white.opacity(0.05))
                        }
                        .clipShape(.circle)
                        .frame(width: 60, height: 60)
                        
                        
                        Circle()
                            .stroke(gradient, lineWidth: 1)
                            .frame(width: 80, height: 80)
                        
                            .rotationEffect(.degrees(rotation))
                            .onAppear {
                                withAnimation(.linear(duration: 20)
                                    .repeatForever(autoreverses: false)) {
                                        rotation = 360
                                    }
                                
                                withAnimation(
                                    .easeInOut(duration: 4)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    opacity = 0.4
                                }
                            }
                        
                        ZStack {
                            if isCaptured {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                                    .imageScale(.large)
                                    .transition(.blurReplace)
                                    .contentShape(.rect)
                            } else {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 70, height: 70)
                                    .transition(.blurReplace)
                            }
                        }
                        .frame(width: 70, height: 70)
                        .contentShape(.rect)
                        .highPriorityGesture(
                            TapGesture()
                                .onEnded {
                                    if !isCaptured {
#if targetEnvironment(simulator)
#else
                                        model.capturePhoto()
#endif
                                    } else {
                                        clearAllInputs()
                                    }
                                    
                                }
                        )
                        
                    }
                    
                    Spacer()
                    
                    if isCaptured {
                        Button {
                            // Coronary disease check
                            if case .loadedImage(let uIImage) = loadState {
                                llm.customUserInput = "Analyze this ECG for signs of coronary artery disease."
                                Task {
                                    // Image is already rotated at capture time
                                    let ciImage = CIImage(image: uIImage)
                                    await llm.generate(image: ciImage ?? CIImage(), videoURL: nil)
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "heart")
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    } else {
                        Button {
#if targetEnvironment(simulator)
#else
                            model.switchCamera()
#endif
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    
                    
                }
            }
            .padding(.horizontal, 40)
            .preferredColorScheme(.dark)
            .animation(.spring, value: isCaptured)
        }
        
        
    }
    
    func clearAllInputs() {
        model.toggleStreaming()
        model.movieURL = nil
        model.photo = nil
        selectedItem = nil
        isCaptured = false
        loadState = .unknown
        llm.output = ""
    }
}


#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
