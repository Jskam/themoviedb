import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:themoviedb/domain/api_client/account_api_client.dart';
import 'package:themoviedb/domain/api_client/movie_api_client.dart';
import 'package:themoviedb/domain/api_client/api_client_exception.dart';
import 'package:themoviedb/domain/data_providers/session_data_provider.dart';
import 'package:themoviedb/domain/entity/movie_details.dart';
import 'package:themoviedb/domain/entity/movie_details_credits.dart';
import 'package:themoviedb/domain/entity/movie_details_video.dart';
import 'package:themoviedb/domain/services/auth_service.dart';
import 'package:themoviedb/ui/navigation/main_navigation.dart';

class MovieDetailsPosterData {
  final String? backdropPath;
  final String? posterPath;
  final bool isFavorite;

  MovieDetailsPosterData({
    this.backdropPath,
    this.posterPath,
    required this.isFavorite,
  });
}

class MovieDetailsNameData {
  final String title;
  final String year;
  MovieDetailsNameData({required this.title, required this.year});
}

class MovieDetailsScoreAndTrailerData {
  final String? trailerKey;
  final double voteAvarage;
  MovieDetailsScoreAndTrailerData({
    this.trailerKey,
    required this.voteAvarage,
  });
}

class MovieDetailsPeopleData {
  final String name;
  final String job;
  MovieDetailsPeopleData({required this.name, required this.job});
}

class MovieDetailsData {
  bool isLoading = true;
  String overview = '';
  MovieDetailsPosterData posterData = MovieDetailsPosterData(isFavorite: false);
  MovieDetailsNameData nameData = MovieDetailsNameData(title: '', year: '');
  MovieDetailsScoreAndTrailerData scoreData =
      MovieDetailsScoreAndTrailerData(voteAvarage: 0);
  String summary = '';
  List<List<MovieDetailsPeopleData>> peopleData = [];
}

class MovieDetailsModel extends ChangeNotifier {
  MovieDetailsModel({required this.movieId});

  final _authService = AuthService();
  final _sessionDataProvider = SessionDataProvider();
  final _movieApiClient = MovieApiClient();
  final _accountApiClient = AccountApiClient();

  MovieDetails? _movieDetails;
  MovieDetailsCredits? _movieDetailsCast;
  MovieDetailsVideo? _movieDetailsVideo;

  final int movieId;
  final data = MovieDetailsData();
  String _locale = '';
  late DateFormat _dateFormat;
  bool _isFavorite = false;

  MovieDetails? get movieDetails => _movieDetails;
  MovieDetailsCredits? get movieDetailsCast => _movieDetailsCast;
  MovieDetailsVideo? get movieDetailsVideo => _movieDetailsVideo;
  bool? get isFavorite => _isFavorite;

  String stringFromDate(DateTime? date) =>
      date != null ? _dateFormat.format(date) : '';

  Future<void> setupLocale(BuildContext context) async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_locale == locale) return;
    _locale = locale;
    _dateFormat = DateFormat.yMMMMd(_locale);
    await loadDetails(context);
  }

  Future<void> loadDetails(BuildContext context) async {
    try {
      _movieDetails = await _movieApiClient.movieDetails(movieId, _locale);
      _movieDetailsCast =
          await _movieApiClient.getCastForMovieDetails(movieId, _locale);
      _movieDetailsVideo =
          await _movieApiClient.getVideosForMovieDetails(movieId, _locale);
      final sessionId = await _sessionDataProvider.getSessionId();
      if (sessionId != null) {
        _isFavorite = await _movieApiClient.isFavorite(movieId, sessionId);
      }
      updateData(_movieDetails, _isFavorite, _movieDetailsCast);
    } on ApiClientException catch (e) {
      _handleApiClientException(e, context);
    }
  }

  void updateData(MovieDetails? details, bool isFavorite,
      MovieDetailsCredits? castDetails) {
    data.isLoading = details == null;
    if (details == null) {
      notifyListeners();
      return;
    }
    data.overview = details.overview ?? '';
    data.posterData = MovieDetailsPosterData(
      backdropPath: details.backdropPath,
      posterPath: details.posterPath,
      isFavorite: isFavorite,
    );
    var year = details.releaseDate?.year.toString();
    year != null ? year = ' ($year)' : '';
    data.nameData = MovieDetailsNameData(title: details.title, year: year!);
    final videos = movieDetailsVideo?.results
        .where((video) => video.type == 'Trailer' && video.site == 'YouTube');
    final trailerKey = videos?.isNotEmpty == true ? videos?.first.key : null;
    data.scoreData = MovieDetailsScoreAndTrailerData(
      voteAvarage: details.voteAverage,
      trailerKey: trailerKey,
    );
    data.summary = makeSummary(details);
    data.peopleData = makePeopleData(castDetails);

    notifyListeners();
  }

  String makeSummary(MovieDetails details) {
    var result = <String>[];

    final releaseDate = details.releaseDate;
    if (releaseDate != null) result.add(stringFromDate(releaseDate));

    final productionCountries = details.productionCountries;
    if (productionCountries.isNotEmpty) {
      result.add('(${productionCountries.first.iso})');
    }

    final runtime = details.runtime ?? 0;
    final duration = Duration(minutes: runtime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    result.add('${hours}h ${minutes}m');

    var genresNames = [];
    final genres = details.genres;
    if (genres.isNotEmpty) {
      for (var genre in genres) {
        genresNames.add(genre.name);
      }
      genresNames.join(', ');
      result.add(genresNames.join(', '));
    }
    return result.join(' ');
  }

  List<List<MovieDetailsPeopleData>> makePeopleData(
      MovieDetailsCredits? details) {
    var crew = details?.crew.map((e) => MovieDetailsPeopleData(name: e.name, job: e.job)).toList();
    if (crew == null || crew.isEmpty) return [];
    crew = crew.length > 4 ? crew.sublist(0, 4) : crew;
    var crewChunks = <List<MovieDetailsPeopleData>>[];
    for (var i = 0; i < crew.length; i += 2) {
      crewChunks.add(
        crew.sublist(i, i + 2 > crew.length ? crew.length : i + 2),
      );
    }
    return crewChunks;
  }

  Future<void> toggleFavorite(BuildContext context) async {
    final accountId = await _sessionDataProvider.getAccountId();
    final sessionId = await _sessionDataProvider.getSessionId();
    if (sessionId == null || accountId == null) return;
    final newFavoriteValue = !_isFavorite;
    _isFavorite = newFavoriteValue;
    notifyListeners();
    try {
      await _accountApiClient.markIsFavorite(
        accountId: accountId,
        sessionId: sessionId,
        mediaType: ApiClientMediaType.movie,
        mediaId: movieId,
        favorite: newFavoriteValue,
      );
    } on ApiClientException catch (e) {
      _handleApiClientException(e, context);
    }
  }

  void _handleApiClientException(
      ApiClientException exception, BuildContext context) {
    switch (exception.type) {
      case ApiClientExceptionType.sessionExpired:
        _authService.logout();
        MainNavigation.resetNavigation(context);
        break;
      default:
        if (kDebugMode) {
          print(exception);
        }
    }
  }
}
