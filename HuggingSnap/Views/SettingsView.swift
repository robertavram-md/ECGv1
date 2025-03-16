//
//  SettingsView.swift
//  SnapECG
//
//  Created by Cyril Zakka on 2/24/25.
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    
    @Environment(\.dismiss) var dismiss
    
    // Support
    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State var isShowingMailView = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Support") {
                    LabeledContent {
                    } label: {
                        Label("Terms of Use", systemImage: "book.pages")
                            .imageScale(.medium)
                    }
                    
                    LabeledContent {
                    } label: {
                        Label("Privacy Policy", systemImage: "lock")
                            .imageScale(.medium)
                    }
                    
                    LabeledContent {
                        Text(Bundle.main.releaseVersionNumberPretty)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label(title: {
                            Text("SnapECG")
                        }, icon: {
                            Image("huggy.fill")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                        })
                        .imageScale(.medium)
                    }
                }
                
                Button(action: {
                    isShowingMailView.toggle()
                }, label: {
                    Label(title: {
                        Text("Contact Us")
                            .foregroundStyle(.primary)
                    }, icon: {
                        Image(systemName: "envelope")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .imageScale(.medium)
                })
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .disabled(!MFMailComposeViewController.canSendMail())
                .sheet(isPresented: $isShowingMailView) {
                    MailView(
                        result: self.$result,
                        recipients: ["support@huggingface.co"],
                        subject: "SnapECG Feedback",
                        messageBody: "Please describe your issue below:\n\n\n\n\n" + UIDevice.getDeviceInfo(),
                        isHTML: false
                    )
                }
                
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
