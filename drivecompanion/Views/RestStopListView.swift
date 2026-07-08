//
//  RestStopListView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 07/07/26.
//

import SwiftUI

struct RestStopListView: View {
    @ObservedObject var restStopViewModel: RestStopViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [RestStopCandidate] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if candidates.isEmpty {
                    ContentUnavailableView(
                        "Belum ketemu tempat istirahat",
                        systemImage: "mappin.slash")
                } else {
                    List(candidates) { candidate in
                        Button {
                            restStopViewModel.openInMaps(candidate)
                            dismiss()
                        } label: {
                            RestStopRow(candidate: candidate)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Tempat Istirahat Terdekat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Tempat Istirahat Terdekat")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .background(.white)
        .task {
            let found = await restStopViewModel.findCandidates()
            candidates = found
            isLoading = false

            for candidate in found {
                let updated = await restStopViewModel.fetchEstimatedTime(for: candidate)
                if let index = candidates.firstIndex(where: { $0.id == updated.id }) {
                    candidates[index] = updated
                }
            }
        }
    }
}
