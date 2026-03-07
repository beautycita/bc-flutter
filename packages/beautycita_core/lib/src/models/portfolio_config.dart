class PortfolioConfig {
  final String? slug;
  final bool isPublic;
  final String theme;
  final String? bio;
  final String? tagline;

  const PortfolioConfig({
    this.slug,
    this.isPublic = false,
    this.theme = 'portfolio',
    this.bio,
    this.tagline,
  });

  factory PortfolioConfig.fromJson(Map<String, dynamic> json) => PortfolioConfig(
    slug: json['portfolio_slug'] as String?,
    isPublic: json['portfolio_public'] as bool? ?? false,
    theme: json['portfolio_theme'] as String? ?? 'portfolio',
    bio: json['portfolio_bio'] as String?,
    tagline: json['portfolio_tagline'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'portfolio_slug': slug,
    'portfolio_public': isPublic,
    'portfolio_theme': theme,
    'portfolio_bio': bio,
    'portfolio_tagline': tagline,
  };
}
