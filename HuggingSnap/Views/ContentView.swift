////
////  ContentView.swift
////  HuggingSnap
////
////  Created by Cyril Zakka on 2/11/25.
////
import AVKit
import PhotosUI
import SwiftUI

// TODO: Stop streaming when not displayed
// TODO: Add video recording

enum LoadState {
    case unknown
    case loading
    case loadedMovie(Video)
    case loadedImage(UIImage)
    case failed
}

struct ContentView: View {
    

    // Control state
    @StateObject private var model = ContentViewModel()
    @State private var isCaptured: Bool = false
    
    // Import from Photos
    @State private var selectedItem: PhotosPickerItem?
    @State private var loadState = LoadState.unknown
    
    // Videos
    @State var player = AVPlayer()
    
    // LLM
    @State var llm = VLMEvaluator()
    @State var isLLMLoaded: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.vertical)
            
            switch loadState {
            case .unknown, .loading, .failed:
#if !targetEnvironment(simulator)
                FrameView(image: model.frame)
                    .edgesIgnoringSafeArea(.vertical)
#endif
            case .loadedMovie(let movie):
                ZStack {
                    Color.clear
                        .edgesIgnoringSafeArea(.vertical)
                }.background {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.vertical)
                        .onAppear() {
                            setupPlayer(with: movie.url)
                        }
                    
                }
                //
            case .loadedImage(let image):
                //                // Handle loaded image
                //                // Little hacky but needed otherwise buttons overflow on edges
                //                // Do not be tempted to remove
                ZStack {
                    Color.clear.edgesIgnoringSafeArea(.vertical)
                }.background {
                    Image(uiImage: image)
                        .resizable()
                        .edgesIgnoringSafeArea(.vertical)
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.vertical)
                    //
                }
                //
            }
        }
        .overlay {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    //                    if !llm.output.isEmpty {
                    MessageView(text: llm.output)
                        .opacity(llm.output.isEmpty ? 0:1)
                    //                    }
                    Spacer()
                    if !isLLMLoaded {
                        Text(llm.modelInfo)
                            .contentTransition(.numericText())
                            .font(.caption)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background {
                                Capsule()
                                    .fill(.regularMaterial)
                            }
                    }
                    ControlView(selectedItem: $selectedItem, isCaptured: $isCaptured, loadState: $loadState)
                        .environmentObject(model)
                        .environment(llm)
                        .padding()
                        .padding(.horizontal, 40)
                        .preferredColorScheme(.dark)
                }
            }
        }
        .overlay {
            if !isLLMLoaded {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .edgesIgnoringSafeArea(.vertical)
                        .transition(.blurReplace)
                    
                    VStack {
                        VStack {
                            Text("Visual Intelligence\nwith Hugging Face")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(

                                        LinearGradient(
                                            colors: [.orange, .yellow],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                .padding(.bottom)
                            
                            Text("Learn about the objects and places around you and get information about what you see")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .padding(.bottom)
                            
                            Text("Photos and videos used are processed entirely on your device. No data is sent to the cloud.")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            //                            .padding(.bottom, 100)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                        
                        Button(action: {
                            // Dismiss
                        }, label: {
                            HStack {
                                ProgressView()
                                Text(llm.modelInfo)
                                    .contentTransition(.numericText())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    
                                //                        .opacity(llm.)
                                    
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .background {
                                Capsule()
                                    .fill(.regularMaterial)
                            }
                        })
                        .tint(.white)
                    }
                    .padding(.horizontal)
                    
                    
                }
            }
        }
        // Detect photo capture
        .onChange(of: model.photo) {
            if let photoData = model.photo {
                isCaptured = true
                if !model.isStreamingPaused {
                    model.toggleStreaming()
                }
                if let uiImage = UIImage(data: photoData) {
                    loadState = .loadedImage(uiImage)
                }
            }
        }
        .onChange(of: model.movieURL) {
            if !model.isRecording {
                if let movieURL = model.movieURL {
                    isCaptured = true
                    if !model.isStreamingPaused {
                        model.toggleStreaming()
                    }
                    loadState = .loadedMovie(Video(url: movieURL))
                }
            }
            
        }
        // Detect photo picker selection
        .onChange(of: selectedItem) {
            if !model.isStreamingPaused {
                model.toggleStreaming()
            }
            Task {
                do {
                    if selectedItem == nil {
                        loadState = .unknown
                    } else {
                        loadState = .loading
                        if let video = try await selectedItem?.loadTransferable(type: Video.self) {
                            // Video
                            loadState = .loadedMovie(video)
                            isCaptured = true
                        } else if let image = try await selectedItem?.loadTransferable(type: Data.self) {
                            // Image
                            if let uiImage = UIImage(data: image) {
                                loadState = .loadedImage(uiImage)
                            }
                            isCaptured = true
                        }
                    }
                    
                    
                } catch {
                    loadState = .failed
                }
            }
        }
        .task {
#if !targetEnvironment(simulator)
            _ = try? await llm.load()
            await MainActor.run {
                withAnimation {
                    isLLMLoaded = true
                }
            }
#endif
        }
    }
    
    private func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        
        // Add loop observation
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        player.play()
    }
}

struct ControlView: View {
    
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
        
        VStack(alignment: .center, spacing: 20) {
            
            if isCaptured {
                HStack(spacing: 20) {
                    if case .loadedImage(let uIImage) = loadState {
                        Button {
                            // Image description
                            Task {
                                let ciImage = CIImage(image: uIImage)
                                await llm.generate(image: ciImage ?? CIImage(), videoURL: nil)
                            }
                            
                        } label: {
                            Label("Describe", systemImage: "text.quote")
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
                    
                    if case .loadedMovie(let video) = loadState {
                        Button {
                            Task {
                                await llm.generate(image: nil, videoURL: video.url)
                            }
                        } label: {
                            Label("Summarize", systemImage: "text.append")
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            HStack {
                PhotosPicker(selection: $selectedItem,
                             matching: .any(of: [.images, .videos])) {
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 50, height: 50)
                        Image(systemName: "photo.fill.on.rectangle.fill")
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
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
                            RoundedRectangle(cornerRadius: scaleDown ? 24:100)
                                .fill(scaleDown ? .red:.white)
                                .frame(width: 70, height: 70)
                                .transition(.blurReplace)
                                .scaleEffect(scaleDown ? 0.65 : 1)
                        }
                    }
                    .frame(width: 70, height: 70)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !model.isRecording {
                                    withAnimation {
                                        scaleDown = true
                                    }
#if targetEnvironment(simulator)
#else
                                    if !model.isRecording {
                                        model.toggleRecording()
                                    }
#endif
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.smooth(duration: 0.1)) {
                                    scaleDown = false
                                }
                                if !isCaptured {
#if targetEnvironment(simulator)
#else
                                    if model.isRecording {
                                        model.toggleRecording()
                                    }
#endif
                                }
                            }
                    )
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
                .disabled(isCaptured)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring, value: isCaptured)
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

struct Video: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "movie.mp4")
            
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

extension AVPlayerViewController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.showsPlaybackControls = false
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
