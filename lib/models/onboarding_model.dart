class OnboardingModel {
  final String title;
  final String description;
  final String image;
  final String? link;

  OnboardingModel({
    required this.title,
    required this.description,
    required this.image,
    this.link,
  });
}