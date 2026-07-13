class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Current selected index
  int currentIndex = 0;
  
  // Function to update index
  void updateIndex(int index) {
    currentIndex = index;
  }
}