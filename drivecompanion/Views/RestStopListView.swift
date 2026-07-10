//
//  RestStopListView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 07/07/26.
//

import SwiftUI
import MapKit

struct RestStopListView: View {
    @ObservedObject var restStopViewModel: RestStopViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var candidates: [RestStopCandidate] = []
    @State private var isLoading = true
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCandidateID: UUID?
    @State private var routeCache: [UUID: MKRoute] = [:]
    
    private var selectedCandidate: RestStopCandidate? {
        candidates.first { $0.id == selectedCandidateID }
    }
    
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
                    VStack(spacing: 0) {
                        routeMap
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        
                        List(candidates) { candidate in
                            Button {
                                selectCandidate(candidate)
                            } label: {
                                RestStopRow(candidate: candidate, isNearest: candidate.id == candidates.first?.id)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        candidate.id == selectedCandidateID
                                        ? Color(red: 232/255, green: 244/255, blue: 251/255)
                                        : Color.clear
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                candidate.id == selectedCandidateID
                                                ? Color(red: 42/255, green: 91/255, blue: 156/255).opacity(0.4)
                                                : Color.clear,
                                                lineWidth: 1)
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                            )
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        
                        if let selectedCandidate {
                            PrimaryButton("Buka di Maps") {
                                restStopViewModel.openInMaps(selectedCandidate)
                                dismiss()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }
                    }
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
            
            guard let closest = found.first else { return }
            selectedCandidateID = closest.id
            await loadRoute(for: closest)
            
            for candidate in found {
                let updated = await restStopViewModel.fetchEstimatedTime(for: candidate)
                if let index = candidates.firstIndex(where: { $0.id == updated.id }) {
                    candidates[index] = updated
                }
            }
        }
    }
    
    @ViewBuilder
    private var routeMap: some View {
        if let origin = restStopViewModel.originCoordinate, let selectedCandidate {
            Map(position: $cameraPosition) {
                Marker("Anda", coordinate: origin)
                    .tint(.blue)
                
                if let route = routeCache[selectedCandidate.id] {
                    MapPolyline(route.polyline)
                        .stroke(
                            Color(red: 42/255, green: 91/255, blue: 156/255),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                } else {
                    MapPolyline(coordinates: [origin, selectedCandidate.coordinate])
                        .stroke(
                            Color(red: 42/255, green: 91/255, blue: 156/255).opacity(0.35),
                            style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                }
                
                Marker(selectedCandidate.name, coordinate: selectedCandidate.coordinate)
                    .tint(.orange)
            }
        } else {
            Color(AppColor.background)
        }
    }
    
    private func selectCandidate(_ candidate: RestStopCandidate) {
        guard candidate.id != selectedCandidateID else { return }
        selectedCandidateID = candidate.id
        updateCameraFromStraightLine(to: candidate)
        Task { await loadRoute(for: candidate) }
    }
    
    private func loadRoute(for candidate: RestStopCandidate) async {
        if routeCache[candidate.id] == nil {
            if let route = await restStopViewModel.fetchRoute(for: candidate) {
                routeCache[candidate.id] = route
            }
        }
        updateCameraFromRoute(for: candidate)
    }
    
    private func updateCameraFromStraightLine(to candidate: RestStopCandidate) {
        guard let origin = restStopViewModel.originCoordinate else { return }
        let coordinates = [origin, candidate.coordinate]
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02))
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
    
    private func updateCameraFromRoute(for candidate: RestStopCandidate) {
        guard let route = routeCache[candidate.id] else { return }
        let region = MKCoordinateRegion(route.polyline.boundingMapRect)
        cameraPosition = .region(MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 1.3,
                longitudeDelta: region.span.longitudeDelta * 1.3)))
    }
}
