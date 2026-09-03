class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Current selected index
  int currentIndex = 0;
  
  // Listeners for index changes
  final List<Function(int)> _listeners = [];
  
  // Function to update index
  void updateIndex(int index) {
    currentIndex = index;
    // Notify all listeners
    for (var listener in _listeners) {
      listener(index);
    }
  }

  // Add listener
  void addListener(Function(int) listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(Function(int) listener) {
    _listeners.remove(listener);
  }
}