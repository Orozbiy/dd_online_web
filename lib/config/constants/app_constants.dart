/// Тиркеменин константалары
class AppConstants {
  // Тиркеме маалымат
  static const String appName = 'DD Online';
  static const String appVersion = '1.0.0';

  // Цубут файлдардын жолдору
  static const String assetsPath = 'assets/';
  static const String imagesPath = '${assetsPath}images/';

  // Башкы сеттиңдери
  static const int gridCrossAxisCount = 2;  // Сеткада 2 мамычалуу издер
  static const int itemsPerPage = 20;       // Бир беттеде 20 товар

  // Анимациялык убактысы
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration longDuration = Duration(milliseconds: 600);

  // Издөө сеттиңдери
  static const int minSearchLength = 2;     // Минимум 2 символ издөө үчүн
  static const int searchDebounceMs = 500;  // Издөөдөн сөзү өнөм салуу
}
