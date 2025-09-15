//
//  BreakingArsenalView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI

struct BreakingArsenalView: View {
    @Binding var selectedTab: TabSelection
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // Move Section
                NavigationLink {
                    MoveListView(onNavigateToAdd: {
                        selectedTab = .add
                    })
                } label: {
                    Text("MOVE")
                        .font(.ibmPlexMono(size: 42, weight: .bold))
                        .foregroundColor(Color(red: 237/255, green: 245/255, blue: 255/255))
                }
                
                // Combo Section
                NavigationLink {
                    ComboListView()
                } label: {
                    Text("COMBO")
                        .font(.ibmPlexMono(size: 42, weight: .bold))
                        .foregroundColor(Color(red: 237/255, green: 255/255, blue: 255/255))
                }
                
                Spacer()
            }
        }
    }
}
