import 'dart:async';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:music_player_bottom_sheet/music_player_bottom_sheet.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin{
  int _tabIndex = 0;
  final double _height = 54.0;
  MusicPlayerAnimationController _playerController;
  StreamController _s = StreamController.broadcast();
  String debug = '';

  Tween<double> map;

  final _tabPages = <Widget>[
    Center(child: Icon(Icons.cloud, size: 64, color: Colors.teal)),
    Center(child: Icon(Icons.alarm, size: 64, color: Colors.cyan)),
    Center(child: Icon(Icons.forum, size: 64, color: Colors.blue)),
  ];
  final _bottomNavigationItems = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.cloud), title: Text('Tab1')),
    BottomNavigationBarItem(icon: Icon(Icons.alarm), title: Text('Tab2')),
    BottomNavigationBarItem(icon: Icon(Icons.forum), title: Text('Tab3'))
  ];

  @override
  void initState() {
    _playerController = MusicPlayerAnimationController(vsync: this,);
    _playerController.addListener(() {
      setState(() {});
    });

    map = Tween<double>(begin: _height, end: 0.0);

    _s.stream.listen((event) {
      setState(() {
        debug += '; ' + event['number'].toString() + ' / ' + event['str'];
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavBar = BottomNavigationBar(
      items: _bottomNavigationItems,
      currentIndex: _tabIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (int index) {
        setState(() {
          _tabIndex = index;
        });
      },
    );
    return SafeArea(
      child:Scaffold(
        body: MusicPlayerSheet(
          animationController: _playerController,
          lowerLayer: _getLowerLayer(),
          upperLayer: _getUpperLayer(),
        ),
        bottomNavigationBar: bottomNavBar,
      ),
    );
  }

  Widget _getLowerLayer() {
    return Scaffold(appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _tabPages[_tabIndex],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RaisedButton(
                    child: Text("Show Player"),
                    onPressed: _show,
                  ),
                ],
              ),
            ],
          ),
        ),
        margin: EdgeInsets.all(10.0),
        color: Colors.cyan[100],
      ),
    );
  }

  void _show() {
    if (_playerController.lowerBound != null) {
      _playerController.launchTo(_playerController.initialValue, _playerController.lowerBound);
    }
  }

  Widget _getUpperLayer() {
    return AnimatedContainer(
      child: Text("$debug"),
      alignment: Alignment.topCenter,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.only(
          topLeft: 
            (_playerController.animationState.value == AnimationState.collapsed ||
                _playerController.animationState.value == AnimationState.hided) ?
                  Radius.circular(0) : Radius.circular(12),
          topRight: 
            (_playerController.animationState.value == AnimationState.collapsed ||
                _playerController.animationState.value == AnimationState.hided) ?
                  Radius.circular(0) : Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 2.5,
            offset: Offset(0,0),
          )
        ]
      ),
      duration: Duration(milliseconds: 100),
    );
  }

}