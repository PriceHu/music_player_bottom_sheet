import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'animation_controller.dart';

import 'package:after_layout/after_layout.dart';

const double _kMinFlingVelocity = 700.0;
const double _kCompleteFlingVelocity = 5000.0;

class MusicPlayerSheet extends StatefulWidget{
  const MusicPlayerSheet({
    Key key,
    @required this.animationController,
    @required this.lowerLayer,
    @required this.upperLayer,
    this.safeAreaPadding = false,
    this.scrollController,
    this.menuLayer,
    this.menuHeight = 54.0,
    this.header,
    this.headerHeight = 64.0,
    this.onDragEnd,
    this.onDragStart,
    this.onTap
  }) : assert(animationController != null),
    super(key: key);

  final ScrollController scrollController;
  final MusicPlayerAnimationController animationController;
  final Widget lowerLayer;
  final Widget upperLayer;
  final bool safeAreaPadding;
  // may be removed
  final Widget menuLayer;
  final double menuHeight;
  final Widget header;
  final double headerHeight;
  final Function() onDragEnd;
  final Function() onDragStart;
  final Function() onTap;

  @override
  State<StatefulWidget> createState() => MusicPlayerSheetState();

}

class MusicPlayerSheetState extends State<MusicPlayerSheet>
  with TickerProviderStateMixin, AfterLayoutMixin<MusicPlayerSheet>{
  
  ScrollController substituteScrollController;
  
  double _screenHeight;
  double _sheetMinimumHeight = 0.0;
  bool _forceScrolling = false;
  bool _enabled = true;
  bool _scrolling = false;
  bool _visible = true;
  // Touch gestures
  Drag _drag;
  ScrollHoldController _hold;
  Offset _lastPosition;

  // key for header
  final GlobalKey _headerKey = GlobalKey();
  // key for the whole widget
  final GlobalKey _widgetKey = GlobalKey(debugLabel: 'MusicPlayerSheet navigation layer key');

  bool get _hasHeader => widget.header != null;
  bool get _shouldScroll => _scrollController != null && _scrollController.hasClients;
  double get widgetHeight {
    final RenderBox renderBox = _widgetKey.currentContext.findRenderObject();
    return renderBox.size.height;
  }
  MusicPlayerAnimationController get animationController => widget.animationController;
  ScrollController get _scrollController => substituteScrollController ?? widget.scrollController;

  set enabled(bool enable) {
    _enabled = enable;
  }
  
  void forceScrolling(bool force) {
    _forceScrolling = force;
    _setScrolling(force);
  }

  void _setScrolling(bool scroll) {
    if (_shouldScroll) {
      _scrolling = scroll;
    }
  }

  void _visibilityListener() {
    setState(() {
      _visible = animationController.visibility.value;
    });
  }

  @override
  void initState() {
    super.initState();
    animationController.visibility.addListener(_visibilityListener);
  }

  @override
  void dispose() {
    animationController.visibility.removeListener(_visibilityListener);
    animationController.dispose();
    super.dispose();
  }

  Widget _buildSlideAnimation(BuildContext context, Widget child) {
    var layout;
    if (widget.menuLayer != null) {
      // TODO optimize menu layer layout
      layout = Stack(
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(bottom: widget.menuHeight),
            child: _buildAnimatedSheet(context, child),
          ),
          // _buildAnimatedSheet(context, child),
          Align(
            alignment: Alignment.bottomCenter,
            child: widget.menuLayer,
          ),
        ]
      );
    } else {
      layout = _buildAnimatedSheet(context, child);
    }
    return GestureDetector(
      // TODO wrap tap to expand
      onTap: widget.onTap,
      onVerticalDragDown: _onVerticalDragDown,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onVerticalDragCancel: _onVerticalDragCancel,
      onVerticalDragStart: _onVerticalDragStart,
      child: layout,
    );
  }

  Widget _buildAnimatedSheet(BuildContext context, Widget child) {
    // TODO restrict value to be between 0 and 1
    var heightFactor = widget.animationController.value >= 0
        ? widget.animationController.value
        : 0.0;
    return FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        heightFactor: heightFactor,
        child: child);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    _screenHeight = screenSize.height;
    var header = Container(
      key: _headerKey,
      height: widget.headerHeight,
      child: widget.header,
    );
    var playerSheet = Stack(
      children: <Widget>[
        header,
        widget.upperLayer,
      ],
    );
    var element;
    if (_visible) {
      element = AnimatedBuilder(
        animation: animationController,
        builder: _buildSlideAnimation,
        child: playerSheet,
      );
    } else {
      element = Container();
    }
    return Stack(
      key: _widgetKey,
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(bottom: _sheetMinimumHeight),
          child: widget.lowerLayer,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: element,
        )
      ],
    );
  }

  // Touch event handlers

  void _onVerticalDragDown(DragDownDetails details) {
    if (_enabled) {
      // TODO check if drag on outside of scroll
      _setScrolling(true);
      if (_shouldScroll) {
        assert(_hold == null);
        _hold = _scrollController.position.hold(_disposeHold);
      }
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_enabled) {
      _lastPosition = details.globalPosition;
      if (_scrolling && _shouldScroll) {
        // _drag might be null if the drag activity ended and called _disposeDrag.
        assert(_hold == null || _drag == null);
        _drag?.update(details);
        if (_scrollController.position.pixels <= 0 &&
            details.primaryDelta > 0 &&
            !_forceScrolling) {
          _setScrolling(false);
          _onVerticalDragCancel();
          if (_scrollController.position.pixels != 0.0) {
            _scrollController.position.setPixels(0.0);
          }
        }
      } else {
        double friction = 1.0;
        // restrict between upper and lower bound
        if (animationController.value >= animationController.upperBound && details.primaryDelta < 0) {
          friction = 0;
        } else if (animationController.value <= animationController.lowerBound && details.primaryDelta > 0) {
          friction = 0;
        }
        double newValue = animationController.value - details.primaryDelta / _screenHeight * friction;
        if (newValue >= animationController.upperBound) {
          newValue = animationController.upperBound;
        } else if (newValue <= animationController.lowerBound) {
          newValue = animationController.lowerBound;
        }

        animationController.value = newValue;

        if (_shouldScroll && animationController.value >= animationController.upperBound) {
          _setScrolling(true);
          var startDetails = DragStartDetails(
            sourceTimeStamp: details.sourceTimeStamp,
            globalPosition: details.globalPosition,
          );
          _hold = _scrollController.position.hold(_disposeHold);
          _drag = _scrollController.position.drag(startDetails, _disposeHold);
        } else {
          _onVerticalDragCancel();
        }
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_enabled) {
      if (widget.onDragEnd != null) {
        var res = widget.onDragEnd();
        if (res != null && !res) {
          return;
        }
      }

      final double flingVelocity = -details.velocity.pixelsPerSecond.dy / _screenHeight;
      if (_scrolling) {
        assert(_hold == null || _drag == null);
        _drag?.end(details);
        assert(_drag == null);
      } else {
        if (details.velocity.pixelsPerSecond.dy > 0 && animationController.value <= animationController.lowerBound) {
          return;
        } else if (details.velocity.pixelsPerSecond.dy < 0 && animationController.value >= animationController.upperBound) {
          return;
        } else if (details.velocity.pixelsPerSecond.dy.abs() > _kCompleteFlingVelocity) {
          animationController.fling(animationController.lowerBound, animationController.upperBound, velocity: flingVelocity);
        } else {
          if (details.velocity.pixelsPerSecond.dy.abs() > _kMinFlingVelocity) {
            animationController.fling(animationController.lowerBound, animationController.upperBound, velocity: flingVelocity);
          } else {
            if (animationController.value > (animationController.upperBound + animationController.lowerBound) / 2) {
                animationController.expand();
            } else {
                animationController.collapse();
            }
          }
        }
      }
    }
  }

  void _onVerticalDragCancel() {
    assert(_hold == null || _drag == null);
    _hold?.cancel();
    _drag?.cancel();
    assert(_hold == null);
    assert(_drag == null);
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_enabled) {
      if (widget.onDragStart != null) {
        widget.onDragStart();
      }
      if (_shouldScroll) {
        assert(_drag == null);
        _drag = _scrollController.position.drag(details, _disposeDrag);
        assert(_drag != null);
        assert(_hold == null);
      }
    }
  }

  void _disposeHold() {
    _hold = null;
  }

  void _disposeDrag() {
    _drag = null;
  }

  @override
  void afterFirstLayout(BuildContext context) {
    double padding = MediaQuery.of(context).padding.top;
    if (widget.safeAreaPadding) {
        animationController.upperBoundValue = MusicPlayerAnimationValue(pixel: widgetHeight - padding);
      }
    setState(() {
      animationController.height = widgetHeight;
      _sheetMinimumHeight = widget.animationController.lowerBoundValue.pixel;
    });
  }

}