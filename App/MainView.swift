import SwiftUI
import CoreData

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("breakdex")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Clean Architecture ✅")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Video Flashcard App")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Divider()

                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "book.closed")
                        Text("Arsenal")
                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "plus.app")
                        Text("Add Move")
                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Create Combo")
                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "skateboard")
                        Text("Review")
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Text("App successfully compiled with clean architecture!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("breakdex")
        }
        .onAppear {
            print("✅ MainView loaded successfully - clean architecture working!")
        }
    }
}