import 'dart:io';
import 'dart:math';

import 'package:aves/model/image_entry.dart';
import 'package:aves/widgets/fullscreen/info_page.dart';
import 'package:aves/widgets/fullscreen/overlay.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:screen/screen.dart';
import 'package:video_player/video_player.dart';

class FullscreenPage extends StatefulWidget {
  final List<ImageEntry> entries;
  final String initialUri;

  const FullscreenPage({
    Key key,
    this.entries,
    this.initialUri,
  }) : super(key: key);

  @override
  FullscreenPageState createState() => FullscreenPageState();
}

class FullscreenPageState extends State<FullscreenPage> with SingleTickerProviderStateMixin {
  bool _isInitialScale = true;
  int _currentHorizontalPage, _currentVerticalPage = 0;
  PageController _horizontalPager, _verticalPager;
  ValueNotifier<bool> _overlayVisible = ValueNotifier(true);
  AnimationController _overlayAnimationController;
  Animation<double> _topOverlayScale;
  Animation<Offset> _bottomOverlayOffset;
  EdgeInsets _frozenViewInsets, _frozenViewPadding;

  List<ImageEntry> get entries => widget.entries;

  @override
  void initState() {
    super.initState();
    final index = entries.indexWhere((entry) => entry.uri == widget.initialUri);
    _currentHorizontalPage = max(0, index);
    _horizontalPager = PageController(initialPage: _currentHorizontalPage);
    _verticalPager = PageController(initialPage: _currentVerticalPage);
    _overlayAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _topOverlayScale = CurvedAnimation(parent: _overlayAnimationController, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInQuart);
    _bottomOverlayOffset = Tween(begin: Offset(0, 1), end: Offset(0, 0)).animate(CurvedAnimation(parent: _overlayAnimationController, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInQuart));
    _overlayVisible.addListener(onOverlayVisibleChange);

    Screen.keepOn(true);
    initOverlay();
  }

  initOverlay() async {
    // wait for MaterialPageRoute.transitionDuration
    // to show overlay after hero animation is complete
    await Future.delayed(Duration(milliseconds: 300));
    onOverlayVisibleChange();
  }

  @override
  void dispose() {
    _overlayVisible.removeListener(onOverlayVisibleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Screen.keepOn(false);
        SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView(
              scrollDirection: Axis.vertical,
              controller: _verticalPager,
              physics: _isInitialScale ? PageScrollPhysics() : NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentVerticalPage = page),
              children: [
                ImagePage(
                  entries: entries,
                  pageController: _horizontalPager,
                  onTap: () => _overlayVisible.value = !_overlayVisible.value,
                  onPageChanged: (page) => setState(() => _currentHorizontalPage = page),
                  onScaleChanged: (state) => setState(() => _isInitialScale = state == PhotoViewScaleState.initial),
                ),
                NotificationListener(
                  onNotification: (notification) {
                    if (notification is BackUpNotification) {
                      _verticalPager.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                    return false;
                  },
                  child: InfoPage(
                    entry: entries[_currentHorizontalPage],
                  ),
                ),
              ],
            ),
            if (_currentHorizontalPage != null && _currentVerticalPage == 0) ...[
              FullscreenTopOverlay(
                entries: entries,
                index: _currentHorizontalPage,
                scale: _topOverlayScale,
                viewInsets: _frozenViewInsets,
                viewPadding: _frozenViewPadding,
              ),
              Positioned(
                bottom: 0,
                child: SlideTransition(
                  position: _bottomOverlayOffset,
                  child: FullscreenBottomOverlay(
                    entries: entries,
                    index: _currentHorizontalPage,
                    viewInsets: _frozenViewInsets,
                    viewPadding: _frozenViewPadding,
                  ),
                ),
              )
            ]
          ],
        ),
        resizeToAvoidBottomInset: false,
//        Hero(
//          tag: uri,
//          child: Stack(
//            children: [
//              Center(
//                child: widget.thumbnail == null
//                    ? CircularProgressIndicator()
//                    : Image.memory(
//                        widget.thumbnail,
//                        width: requestWidth,
//                        height: requestHeight,
//                        fit: BoxFit.contain,
//                      ),
//              ),
//              Center(
//                child: FadeInImage(
//                  placeholder: MemoryImage(kTransparentImage),
//                  image: FileImage(File(path)),
//                  fadeOutDuration: Duration(milliseconds: 1),
//                  fadeInDuration: Duration(milliseconds: 200),
//                  width: requestWidth,
//                  height: requestHeight,
//                  fit: BoxFit.contain,
//                ),
//              ),
//            ],
//          ),
//        ),
      ),
    );
  }

  onOverlayVisibleChange() async {
    if (_overlayVisible.value) {
      SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
      _overlayAnimationController.forward();
    } else {
      final mediaQuery = MediaQuery.of(context);
      _frozenViewInsets = mediaQuery.viewInsets;
      _frozenViewPadding = mediaQuery.viewPadding;
      SystemChrome.setEnabledSystemUIOverlays([]);
      await _overlayAnimationController.reverse();
      _frozenViewInsets = null;
      _frozenViewPadding = null;
    }
  }
}

class ImagePage extends StatefulWidget {
  final List<ImageEntry> entries;
  final PageController pageController;
  final VoidCallback onTap;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<PhotoViewScaleState> onScaleChanged;

  const ImagePage({
    this.entries,
    this.pageController,
    this.onTap,
    this.onPageChanged,
    this.onScaleChanged,
  });

  @override
  State<StatefulWidget> createState() => ImagePageState();
}

class ImagePageState extends State<ImagePage> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PhotoViewGallery.builder(
      itemCount: widget.entries.length,
      builder: (galleryContext, index) {
        final entry = widget.entries[index];
        if (entry.isVideo) {
          final screenSize = MediaQuery.of(galleryContext).size;
          final videoAspectRatio = entry.width / entry.height;
          final childWidth = min(screenSize.width, entry.width);
          final childHeight = childWidth / videoAspectRatio;
          debugPrint('ImagePageState video path=${entry.path} childWidth=$childWidth childHeight=$childHeight var=$videoAspectRatio car=${childWidth / childHeight}');

          return PhotoViewGalleryPageOptions.customChild(
            child: AvesVideo(entry: entry),
            childSize: Size(childWidth, childHeight),
            // no heroTag because `Chewie` already internally builds one with the videoController
            minScale: PhotoViewComputedScale.contained,
            initialScale: PhotoViewComputedScale.contained,
            onTapUp: (tapContext, details, value) => widget.onTap?.call(),
          );
        }
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(entry.path)),
          heroTag: entry.uri,
          minScale: PhotoViewComputedScale.contained,
          initialScale: PhotoViewComputedScale.contained,
          onTapUp: (tapContext, details, value) => widget.onTap?.call(),
        );
      },
      loadingChild: Center(
        child: CircularProgressIndicator(),
      ),
      pageController: widget.pageController,
      onPageChanged: widget.onPageChanged,
      scaleStateChangedCallback: widget.onScaleChanged,
      transitionOnUserGestures: true,
      scrollPhysics: BouncingScrollPhysics(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class AvesVideo extends StatefulWidget {
  final ImageEntry entry;

  const AvesVideo({Key key, this.entry}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AvesVideoState();
}

class AvesVideoState extends State<AvesVideo> {
  VideoPlayerController videoPlayerController;
  ChewieController chewieController;

  @override
  void initState() {
    super.initState();
    videoPlayerController = VideoPlayerController.file(
      File(widget.entry.path),
      // ensure the first frame is shown after the video is initialized
    )..initialize().then((_) => setState(() {}));
    chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
    );
  }

  @override
  void dispose() {
    videoPlayerController.dispose();
    chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Chewie(
      controller: chewieController,
    );
  }
}
