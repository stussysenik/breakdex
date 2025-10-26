## 1. Add Video Player State Management
- [x] 1.1 Add video player state properties to ComboDetailView
- [x] 1.2 Add loading state management for video loading operations
- [x] 1.3 Add error state handling for failed video loads

## 2. Implement Video Player Section
- [x] 2.1 Create video player view section in ComboDetailView layout
- [x] 2.2 Add loading indicator during video loading
- [x] 2.3 Add error state display for failed video loads
- [x] 2.4 Add empty state when no move is selected

## 3. Connect Timeline to Video Player
- [x] 3.1 Update timeline node selection handler to trigger video loading
- [x] 3.2 Implement video loading function using PhotosAssetLoader
- [x] 3.3 Add reactive video loading using task(id:) modifier
- [x] 3.4 Handle player lifecycle (play/pause on view appear/disappear)

## 4. Add Video Loading Logic
- [x] 4.1 Implement async video loading from Photos library
- [x] 4.2 Create AVPlayer instance from loaded video asset
- [x] 4.3 Handle loading state updates and error conditions
- [x] 4.4 Add proper cleanup when switching videos

## 5. Integration Testing
- [x] 5.1 Test timeline node taps trigger video loading
- [x] 5.2 Test loading states display correctly
- [x] 5.3 Test error handling for missing videos
- [x] 5.4 Test player controls and video playback
- [x] 5.5 Test view lifecycle management (play/pause behavior)