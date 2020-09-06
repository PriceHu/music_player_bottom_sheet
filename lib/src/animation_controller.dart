import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

// Default critically damped spring
final SpringDescription _kFlingSpringDefaultDescription = SpringDescription.withDampingRatio(mass: 1, stiffness: 500.0, ratio: 1.0,);

const Tolerance _kFlingTolerance = Tolerance(
  velocity: double.infinity,
  distance: 0.00001,
);

enum AnimationState {
  hided,
  expanded,
  collapsed,
  animating,
}

class MusicPlayerAnimationValue {
  double percentage;
  double pixel;
  MusicPlayerAnimationValue({this.percentage, this.pixel});
  @override
  String toString() {
    return "[percentage: $percentage / pixel: $pixel]";
  }
}

class MusicPlayerAnimationController extends Animation<double>
  with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {

  final AnimationBehavior animationBehavior;
  final String debugLabel;
  
  MusicPlayerAnimationValue lowerBoundValue;
  MusicPlayerAnimationValue upperBoundValue = MusicPlayerAnimationValue(percentage: 1.0);
  double initialValue = 0.0;
  bool showAfterStart;
  Duration duration;
  ValueNotifier<AnimationState> animationState = ValueNotifier(AnimationState.hided);

  Duration _lastElapsedDuration;
  double _widgetHeight = 0.0;
  double _value = 0.0;
  Ticker _ticker;
  Simulation _simulation;
  AnimationStatus _status = AnimationStatus.completed;
  SpringDescription _springDescription = _kFlingSpringDefaultDescription;

  double get lowerBound => lowerBoundValue.percentage;
  double get upperBound => upperBoundValue.percentage;
  Animation<double> get view => this;
  double get velocity {
    if (!isAnimating)
      return 0.0;
    return _simulation.dx(lastElapsedDuration.inMicroseconds.toDouble() / Duration.microsecondsPerSecond);
  }

  bool get isAnimating => _ticker != null && _ticker.isActive;
  Duration get lastElapsedDuration => _lastElapsedDuration;

  @override
  double get value => _value;

  @override
  AnimationStatus get status => _status;

  set height(double value) {
    _widgetHeight = value;
    syncAnimationValues();
    // value = _value; // ?
  }

  set value(double newValue) {
    assert(newValue != null);
    stop();
    _internalSetValue(newValue);
    notifyListeners();
    _checkState();
  }

  set springDescription(description) {
    _springDescription = description;
  }
  
  MusicPlayerAnimationController({
    this.lowerBoundValue,
    this.duration = const Duration(milliseconds: 250),
    this.debugLabel,
    this.showAfterStart = false,
    this.animationBehavior = AnimationBehavior.normal,
    springDescription,
    @required TickerProvider vsync,
  }) : assert(vsync != null) {
    _ticker = vsync.createTicker(_tick);
    if (lowerBoundValue == null) {
      lowerBoundValue = MusicPlayerAnimationValue(pixel: 64.0);
    }
    if (springDescription != null) {
      _springDescription = springDescription;
    }
    if (lowerBound != null) {
      _internalSetValue(showAfterStart ? lowerBound : initialValue);
    }
    animationState.value = showAfterStart ? AnimationState.collapsed : AnimationState.hided;
  }

  void reset() {
    value = showAfterStart ? lowerBound : initialValue;
  }
  
  void _internalSetValue(double newValue) {
    _value = newValue;
  }

  void _checkState() {
    var roundValue = double.parse(value.toStringAsFixed(3));
    var roundLowerBound = double.parse(lowerBound.toStringAsFixed(3));
    var roundUpperBound = double.parse(upperBound.toStringAsFixed(3));

    if (roundValue == roundLowerBound) {
      animationState.value = AnimationState.collapsed;
      _value = lowerBound;
    } else if (roundValue == roundUpperBound) {
      animationState.value = AnimationState.expanded;
      _value = upperBound;
    } else {
      if (roundValue < roundLowerBound && animationState.value == AnimationState.hided) {
        animationState.value = AnimationState.hided;
      } else {
        animationState.value = AnimationState.animating;
      }
    }
  }

  void syncAnimationValues() {
    // sets initial value if lower bound has only pixel value
    if(initialValue == null && lowerBound == null) {
      _value = lowerBoundValue.pixel / _widgetHeight;
    }
    if(lowerBoundValue.pixel != null) {
      lowerBoundValue.percentage = lowerBoundValue.pixel / _widgetHeight;
    }
    if(upperBoundValue.pixel != null) {
      upperBoundValue.percentage = upperBoundValue.pixel / _widgetHeight;
    }
  }

  TickerFuture expand({ double from }) {
    return animateTo(from: from, to: upperBound);
  }

  TickerFuture collapse({ double from }) {
    return animateTo(from: from, to: lowerBound);
  }

  TickerFuture animateTo({ double from, double to, Curve curve = Curves.fastOutSlowIn }) { 
    assert(() {
      if (duration == null) {
        throw FlutterError(
            'AnimationController.collapse() called with no default Duration.\n'
                'The "duration" property should be set, either in the constructor or later, before '
                'calling the collapse() function.'
        );
      }
      return true;
    }());
    if (from != null)
      value = from;
    return _animateToInternal(to, curve: curve);
  }

  TickerFuture fling(double from, double to, { double velocity = 1.0, AnimationBehavior animationBehavior }) {
    final double target = velocity < 0.0 ? from : to;
    return launchTo(value,target,velocity: velocity, animationBehavior: animationBehavior);
  }

  TickerFuture launchTo(double from, double to, { double velocity = 1.0, AnimationBehavior animationBehavior }) {
    double scale = 1.0;
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 200.0;
          break;
        case AnimationBehavior.preserve:
          break;
      }
    }
    
    final Simulation simulation = SpringSimulation(_springDescription, from, to, velocity * scale)
      ..tolerance = _kFlingTolerance;
    return animateWith(simulation);
  }

  TickerFuture animateWith(Simulation simulation) {
    stop();
    return _startSimulation(simulation);
  }

  TickerFuture _animateToInternal(double target, { Curve curve = Curves.easeOut, AnimationBehavior animationBehavior }) {
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
    double scale = 1.0;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 0.05;
          break;
        case AnimationBehavior.preserve:
          break;
      }
    }
    Duration simulationDuration = duration;
    if (simulationDuration == null) {
      assert(() {
        if (this.duration == null) {
          throw FlutterError(
              'AnimationController.animateTo() called with no explicit Duration and no default Duration.\n'
                  'Either the "duration" argument to the animateTo() method should be provided, or the '
                  '"duration" property should be set, either in the constructor or later, before '
                  'calling the animateTo() function.'
          );
        }
        return true;
      }());
      final double range = upperBound - lowerBound;
      final double remainingFraction = range.isFinite ? (target - _value).abs() / range : 1.0;
      simulationDuration = this.duration * remainingFraction;
    } else if (target == value) {
      // Already at target, don't animate.
      simulationDuration = Duration.zero;
    }
    stop();
    if (simulationDuration == Duration.zero) {
      if (value != target) {
        _value = target;
        notifyListeners();
      }
      _status = AnimationStatus.completed;
      _checkState();
      return TickerFuture.complete();
    }
    assert(simulationDuration > Duration.zero);
    assert(!isAnimating);
    // return _startSimulation(_InterpolationSimulation(_value, target, simulationDuration, curve, scale));
    return _startSimulation(SpringSimulation(_springDescription, _value, target, 0)..tolerance = _kFlingTolerance);
  }

  TickerFuture _startSimulation(Simulation simulation) {
    assert(simulation != null);
    assert(!isAnimating);
    _simulation = simulation;
    _lastElapsedDuration = Duration.zero;
    _value = simulation.x(0.0);
    final TickerFuture result = _ticker.start();
    _status = AnimationStatus.forward;
    notifyStatusListeners(_status);
    return result;
  }

  void resync(TickerProvider vsync) {
    final Ticker oldTicker = _ticker;
    _ticker = vsync.createTicker(_tick);
    _ticker.absorbTicker(oldTicker);
  }

  ValueNotifier<bool> visibility = ValueNotifier(true);
  void setVisibility(bool show) {
    visibility.value = show;
  }

  void stop({bool canceled = true}) {
    _simulation = null;
    _lastElapsedDuration = null;
    _ticker.stop(canceled: canceled);
  }

  @override
  void dispose() {
    assert(() {
      if (_ticker == null) {
        throw FlutterError(
            'AnimationController.dispose() called more than once.\n'
                'A given $runtimeType cannot be disposed more than once.\n'
                'The following $runtimeType object was disposed multiple times:\n'
                '  $this'
        );
      }
      return true;
    }());
    _ticker.dispose();
    _ticker = null;
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    final double elapsedInSeconds = elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    assert(elapsedInSeconds >= 0.0);
    _value = _simulation.x(elapsedInSeconds);
    if (_simulation.isDone(elapsedInSeconds)) {
      _stopTick();
    } else if (elapsedInSeconds > 0) {
      // set bounded value
      if (_value < lowerBound && animationState.value != AnimationState.hided) {
        // no lower than lower bound only if launch from hided
        _value = lowerBound;
        _stopTick();
      } else if (_value > upperBound) {
        // no higher than upper bound
        _value = upperBound;
        _stopTick();
      }
    }
    notifyListeners();
  }

  void _stopTick() {
    _status = AnimationStatus.completed;
    notifyStatusListeners(_status);
    stop();
    _checkState();
  }

  @override
  String toStringDetails() {
    final String paused = isAnimating ? '' : '; paused';
    final String ticker = _ticker == null ? '; DISPOSED' : (_ticker.muted ? '; silenced' : '');
    final String label = debugLabel == null ? '' : '; for $debugLabel';
    final String more = '${super.toStringDetails()} ${value.toStringAsFixed(3)}';
    String state = '; ';
    switch (animationState.value) {
      case AnimationState.animating:
        state += 'animating';
        break;
      case AnimationState.collapsed:
        state += 'collapsed';
        break;
      case AnimationState.expanded:
        state += 'expanded';
        break;
      case AnimationState.hided:
        state += 'hided';
        break;
    }
    final String tooLow = "; _value < lowerBound ?" + (lowerBound == null ? false : _value < lowerBound).toString();
    final String tooHigh = "; _value > upperBound ?" + (upperBound == null ? false : _value > upperBound).toString();
    return '$more$paused$ticker$label$state$tooLow$tooHigh';
  }
}

class _InterpolationSimulation extends Simulation {
  _InterpolationSimulation(this._begin, this._end, Duration duration, this._curve, double scale)
      : assert(_begin != null),
        assert(_end != null),
        assert(duration != null && duration.inMicroseconds > 0),
        _durationInSeconds = (duration.inMicroseconds * scale) / Duration.microsecondsPerSecond;

  final double _durationInSeconds;
  final double _begin;
  final double _end;
  final Curve _curve;

  @override
  double x(double timeInSeconds) {
    final double t = (timeInSeconds / _durationInSeconds).clamp(0.0, 1.0);
      return _begin + (_end - _begin) * _curve.transform(t);
  }

  @override
  double dx(double timeInSeconds) {
    final double epsilon = tolerance.time;
    return (x(timeInSeconds + epsilon) - x(timeInSeconds - epsilon)) / (2 * epsilon);
  }

  @override
  bool isDone(double timeInSeconds) => timeInSeconds > _durationInSeconds;
}