# ObjectDetection

This project is based on [ObjectDetection sample](https://github.com/hollance/coreml-survival-guide/tree/master/MobileNetV2%2BSSDLite/ObjectDetection).

The goal of this project is to extend the original project to be able to load video files, and once any human is detected, it starts to record a new video and save it to Photo app.

## Architecture

It follows the original architecture, only add a button in the original view controller to the added features.

There are two primary pages are added:
1. video loader
2. processing page

Couple classes are created for different purpose.
1. DownloadManager
2. PhotoAlbum
3. HumanDetector
4. VideoRecording

And a helper function called `loadTracks` to load the asset.

## Views

### DemoVideoLoaderViewController

It's a quick access list for the demo videos. The videos aren't saved locally when the app is installed. When the user selected any item, it will start to download the video from the [original Github page](https://github.com/intel-iot-devkit/sample-videos). When the download process begins, a small view (DownloadingMonitorViewController) which presenting download progress is show.

Also a button on the right nav bar is the image picker that allows user to pick any his/her own videos from Photo app.

### VideoProcessViewController

This view shows the progress of human detection and a preview result. And while human is detected, a recording indicator is shown as a prompt.

## Processor

### DownloadManager

Due to the demo videos aren't bundled in the app, it has to be downloaded at the first to use. When a video files is requested, it will:
1. try to find if it's saved in `Document` folder of the app sandbox.
2. if not, a download task will start.
3. once the file is downloaded, it will be saved in `Document` folder and notify the caller.

### PhotoAlbum

PhotoAlbum is a helper to authorize the Photo library access and transfer the recorded video to the album.

It will try to create an album called `### Human Detection` and all the future saved videos will be kept there. Using an album to collect the output videos is considering the convenience of the tester, to make it to be managed easier.

### HumanDetector

HumanDetector is the primary object that processes the video frames. It does:
1. get frames in the video
2. check if human detected.
3. if human detected, it triggers recording session and update priview image.
4. generate preview image in UIImage form to be shown on UI

### VideoRecording

This class handles the recording process.

When the first frames is received, it kept the start time. All the frames received will adjust presentation time based on the start time, to put the frame in the right time.

When the recording is done, it saves the file and notify it's creator - HumanDetector. Then the latter will trigger a finish event. 

## UI Creation/ Layout

All the UI are built in code. A Pod called `SnapShot` is installed to help doing the handy auto layout stuff.

## Threading

Almost all the heavy work are done in background thread to prevent any possibility slowing down the UI.

## Event Pub/Sub

In this project, only simple closure style is used. Not like I don't like the RxSwift, it just too heavy for a small project.

Any view controller I built is not handling any heavy task, all the important process are placed in corresponding class.

View controllers bind necessary events for updating the UI state when the source is created.

## Some Pitfalls

### Image/Video Orientation

The orientation of video reminds me the good old day of UIImage orientation. It was found when the image picker is integrated. The sample videos are very clean that won't show you any sign of the orientation issue.

### Memory

During the development, a second thread (queue) was created to process the drawing of bounding boxes and UIImage generation. The process time is reduced but since it's faster, more resources are held in memory simultaneously. I don't think I will have enough time to fine tune it, so the second thread was removed.

### Threading

The closure style pub/sub is easy to generate threading issue due to the caller maybe in background thread and the callee are mostly take the event to update UI which needs to be done in main thread.

## A Tiny Little Trick

When draw the bounding boxes, a rectangle represents of the render target is created. And then 1/2 width of the stroke area is inset to make the strokes are all drawn in the scene. It may be not fancy but it makes the result more confortable especially when the width of stroke is thick.

```swift
let inset = max(strokeWidth / 2, 1)
let frame = CGRect(x: 0, y: 0, width: width, height: height)
    .insetBy(dx: inset,
             dy: inset)
```

It's achieved by intersecting the inseted frame.

```swift
boundingBoxes
    .map { $0.boundingBox.applying(scale) }
    .map { $0.intersection(frame) }
    .forEach { context.stroke($0, width: strokeWidth) }
```

I