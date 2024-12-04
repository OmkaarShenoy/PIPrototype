import 'dart:async';

import 'dart:html' as html;

import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';



void main() {

  runApp(const MyApp());

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'Video Frame Extractor',

      theme: ThemeData(

        primarySwatch: Colors.blue,

      ),

      home: const VideoFrameExtractorPage(),

    );

  }

}



class VideoFrameExtractorPage extends StatefulWidget {

  const VideoFrameExtractorPage({super.key});



  @override

  _VideoFrameExtractorPageState createState() =>

      _VideoFrameExtractorPageState();

}



class _VideoFrameExtractorPageState extends State<VideoFrameExtractorPage> {

  html.VideoElement? _videoElement;

  html.CanvasElement? _canvasElement;

  int totalFrames = 0;

  int fps = 30; // Adjust based on your video's frame rate

  TextEditingController frameNumberController = TextEditingController();

  Uint8List? selectedFrame;

  bool isPlaying = false;

  Timer? _playbackTimer;

  int currentFrame = 0;



  // Zoom level

  double zoomLevel = 1.0;



  // Initialize a unique view type for the VideoElement

  final String _videoElementViewType = 'video-element-view';



  @override

  void initState() {

    super.initState();

    _initializeKeyboardControls();
     debugPrint('VideoFrameExtractorPage initialized.');

  }



void _initializeKeyboardControls() {
    debugPrint('Initializing keyboard controls...');
    html.document.onKeyDown.listen((event) {
      debugPrint('Key pressed: ${event.key}');
      if (event.key == '+') {
        setState(() {
          zoomLevel = (zoomLevel + 0.1).clamp(0.5, 5.0); // Max zoom is 5x
          debugPrint('Zoom level increased to $zoomLevel');
        });
      } else if (event.key == '-') {
        setState(() {
          zoomLevel = (zoomLevel - 0.1).clamp(0.5, 5.0); // Min zoom is 0.5x
          debugPrint('Zoom level decreased to $zoomLevel');
        });
      } else if (event.key == ' ') {
        // Toggle play/pause
        setState(() {
          isPlaying ? _pauseVideo() : _playVideo();
          debugPrint(isPlaying ? 'Video playing...' : 'Video paused.');
        });
      } else if (event.key == 'ArrowRight') {
        // Seek forward
        _seekForward();
        debugPrint('Seeking forward...');
      } else if (event.key == 'ArrowLeft') {
        // Seek backward
        _seekBackward();
        debugPrint('Seeking backward...');
      } else {
        debugPrint('No action for key: ${event.key}');
      }
    });
  }



  Future<void> _pickVideo() async {

    final result = await FilePicker.platform.pickFiles(type: FileType.video);



    if (result != null) {

      final fileBytes = result.files.single.bytes;

      final blob = html.Blob([fileBytes!]);

      final url = html.Url.createObjectUrl(blob);



      // Initialize video element

      _videoElement = html.VideoElement()

        ..src = url

        ..autoplay = false

        ..controls = false // Hide default controls

        ..preload = 'auto';



      // Listen to metadata to get dimensions and duration

      _videoElement!.onLoadedMetadata.listen((_) {

        final videoWidth = _videoElement!.videoWidth;

        final videoHeight = _videoElement!.videoHeight;



        // Dynamically set canvas dimensions

        _canvasElement =

            html.CanvasElement(width: videoWidth, height: videoHeight);



        setState(() {

          totalFrames = (_videoElement!.duration * fps).round();

          currentFrame = 0;

        });

      });



      setState(() {});

    }

  }



  Future<void> _captureFrame(int frameNumber) async {

    if (_videoElement == null || _canvasElement == null) return;



    final time = frameNumber / fps;

    _videoElement!.currentTime = time;



    // Wait for the video to seek to the desired time

    await _videoElement!.onSeeked.first;



    final context = _canvasElement!.context2D;

    context.drawImage(_videoElement!, 0, 0);



    final blob = await _canvasElement!.toBlob('image/jpeg');



    final reader = html.FileReader();

    final completer = Completer<Uint8List>();



    reader.onLoadEnd.listen((event) {

      if (reader.result is Uint8List) {

        completer.complete(reader.result as Uint8List);

      } else if (reader.result is ByteBuffer) {

        completer.complete(Uint8List.view((reader.result as ByteBuffer)));

      } else {

        completer.completeError('Failed to read blob');

      }

    });



    reader.readAsArrayBuffer(blob);

    final frameData = await completer.future;



    setState(() {

      selectedFrame = frameData;

    });

  }

  void _playVideo() {
    if (_videoElement == null || _canvasElement == null) return;

    if (isPlaying) return;

    isPlaying = true;

    _playbackTimer = Timer.periodic(
        Duration(milliseconds: (1000 / fps).round()), (timer) async {
      if (currentFrame >= totalFrames) {
        _pauseVideo();
        return;
      }
      await _captureFrame(currentFrame);
      setState(() {
        currentFrame++;
      });
    });

    setState(() {});
  }

  void _pauseVideo() {
    if (_playbackTimer != null) {
      _playbackTimer!.cancel();
      _playbackTimer = null;
    }
    setState(() {
      isPlaying = false;
    });
  }

  void _seekForward() async {
    if (_videoElement == null || _canvasElement == null) return;

    int seekFrames = 1; // Number of frames to skip forward
    int targetFrame = currentFrame + seekFrames;
    if (targetFrame >= totalFrames) {
      targetFrame = totalFrames - 1;
    }
    currentFrame = targetFrame;
    await _captureFrame(currentFrame);
    setState(() {});
  }

  void _seekBackward() async {
    if (_videoElement == null || _canvasElement == null) return;

    int seekFrames = 1; // Number of frames to skip backward
    int targetFrame = currentFrame - seekFrames;
    if (targetFrame < 0) {
      targetFrame = 0;
    }
    currentFrame = targetFrame;
    await _captureFrame(currentFrame);
    setState(() {});
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _videoElement?.pause();
    _videoElement?.remove();
    _canvasElement?.remove();
    frameNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eagle Eyes Scan for SAR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings action
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[200],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: _pickVideo,
                      child: const Text('Pick Video'),
                    ),
                  ),
                  if (totalFrames > 0)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Total Frames: $totalFrames'),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: frameNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Enter frame number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        final frameNumber =
                            int.tryParse(frameNumberController.text);
                        if (frameNumber != null &&
                            frameNumber < totalFrames &&
                            frameNumber >= 0) {
                          setState(() {
                            currentFrame = frameNumber;
                          });
                          _captureFrame(currentFrame);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Invalid frame number')),
                          );
                        }
                      },
                      child: const Text('Show Frame'),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          title: const Text('Video 1'),
                          subtitle: const Text('Duration: 0:10'),
                          onTap: () {
                            // Logic to play video 1
                          },
                        ),
                        ListTile(
                          title: const Text('Video 2'),
                          subtitle: const Text('Duration: 0:15'),
                          onTap: () {
                            // Logic to play video 2
                          },
                        ),
                        // Add more video items as needed
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Panel - Video Display
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    
                    child: ClipRect(

                      child: Center(

                        child: selectedFrame != null

                            ? Transform.scale(
                                scale: zoomLevel,
                                child: Image.memory(
                                  selectedFrame!,
                                  width: 640,
                                  height: 360,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Text(

                                'Awaiting Input\nClick on a video to view',

                                style: TextStyle(color: Colors.white),

                                textAlign: TextAlign.center,

                              ),
                            ),
                    ),
                  ),
                ),
                // Seek Bar
                if (totalFrames > 0)
                  Slider(
                    value: currentFrame.toDouble(),
                    min: 0,
                    max: (totalFrames - 1).toDouble(),
                    onChanged: (value) async {
                      final targetFrame = value.toInt();
                      currentFrame = targetFrame;
                      await _captureFrame(currentFrame);
                      setState(() {});
                    },
                  ),
                // Playback Controls
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: _seekBackward,
                      ),
                      IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: isPlaying ? _pauseVideo : _playVideo,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed: _seekForward,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
