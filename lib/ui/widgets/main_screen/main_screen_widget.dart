import 'package:flutter/material.dart';
import 'package:themoviedb/constants/constants.dart';
import 'package:themoviedb/domain/data_providers/session_data_provider.dart';
import 'package:themoviedb/domain/factories/screen_factory.dart';


class MainScreenWidget extends StatefulWidget {
  const MainScreenWidget({Key? key}) : super(key: key);
  @override
  State<MainScreenWidget> createState() => _MainScreenWidgetState();
}

class _MainScreenWidgetState extends State<MainScreenWidget> {
  int _selectedTab = 0;
  final _screenFactory = ScreenFactory();

  void onSelectTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          onPressed: () => SessionDataProvider().setSessionId(null),
          icon: const Icon(Icons.logout, color: whiteColor),
        ),
        title: const Image(
          image: AssetImage('assets/images/logo.png'),
          fit: BoxFit.fitHeight,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person, color: whiteColor),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: secondaryColor),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _screenFactory.makeNewsList(),
          _screenFactory.makeMovieList(),
          _screenFactory.makeTvShowList(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        elevation: 0,
        backgroundColor: primaryColor,
        selectedItemColor: secondaryColor,
        unselectedItemColor: unselectedItem,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_outlined),
            label: 'Новости',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_filter),
            label: 'Фильмы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: 'Сериалы',
          ),
        ],
        onTap: onSelectTab,
      ),
    );
  }
}
