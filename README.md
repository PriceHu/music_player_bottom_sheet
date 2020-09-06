# music_player_bottom_sheet

An Apple-Music-like material bottom sheet implementation for music player.

This package was initially developed for use in our Flutter app at [VtuberMusic](https://vtbmusic.com) ([Github Page](https://github.com/vtbmusic)).

## Getting Started

This package can create an Apple-Music-like bottom sheet to hold the player page and content page(s). To use this package, add the dependency to your package's `pubspec.yaml` file:

```yaml
dependencies:
  music_player_bottom_sheet:
    git: https://github.com/PriceHu/music_player_bottom_sheet.git
    # or you can use this address if you cannot access github easily
    # git: https://dev.azure.com/UchidaKotori/vtb-music/_git/music_player_bottom_sheet
```

Then run

```shell
$ flutter pub get
```

and import your project using:

```dart
import 'package:music_player_bottom_sheet/music_player_bottom_sheet.dart';
```

To get the animation ticker add `SingleTickerProviderStateMixin` to the `State` containing the bottom sheet.

```dart
class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin{
    // ...
}
```

Then create the `MusicPlayerAnimationController` object that controls the bottom sheet animation.

```dart
  @override
  void initState() {
    _controller = MusicPlayerAnimationController(vsync: this,);

    super.initState();
  }
```

The default animation controller contains a `SpringDescription` that describes a critically damped spring used to control the animation. You can customize it by passing your own `SpringDescription`:

```dart
// import physics package to use SpringDescription
import 'package:flutter/physics.dart';

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin{
  // ...

  // for example
  final SpringDescription mSpringDescription = SpringDescription.withDampingRatio(mass: 1, stiffness: 500.0, ratio: 0.5,);

  @override
  void initState() {
    _controller = MusicPlayerAnimationController(
      vsync: this,
      // add spring description
      springDescription: mSpringDescription,
    );

    super.initState();
  }
}
```

Note that the animation was constructed so that the bottom sheet will never exceed the upper and lower bound height after launched from hiding.

Finally you can add the bottom sheet to your layout:

```dart
RubberBottomSheet(
    contentLayer: _getLowerLayer(), // The underlying page (Widget)
    playerLayer: _getUpperLayer(), // The bottom sheet content (Widget)
    animationController: _controller, // The one we created earlier
)
```

## License

```text
Licensed under BSD 2-Clause
```

See [LICENSE](./LICENSE)

## Acknowledgement

This project is based on or derives from [Rubber](https://github.com/mcrovero/rubber), with little changes to fit our needs. `Rubber` is licensed under BSD 2-Clause.
