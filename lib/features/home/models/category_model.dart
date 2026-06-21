class CategoryModel {
  final String id;
  final String name;    // кыргызча
  final String nameRu; // орусча
  final String icon;
  final String color;
  final List<SubCategoryModel> subcategories;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.icon,
    required this.color,
    this.subcategories = const [],
  });

  /// Тилге жараша ат кайтарат
  String localizedName(String langCode) =>
      langCode == 'ru' ? nameRu : name;

  static List<CategoryModel> getCategories() {
    return [
      const CategoryModel(
        id: '1', name: 'Кийим-кече', nameRu: 'Одежда', icon: '👕', color: 'FF6B6B',
        subcategories: [
          SubCategoryModel(id: '1_1',  name: 'Баары',           nameRu: 'Все',              icon: '👕'),
          SubCategoryModel(id: '1_2',  name: 'Эркектер',        nameRu: 'Мужская',          icon: '👔'),
          SubCategoryModel(id: '1_3',  name: 'Аялдар',          nameRu: 'Женская',          icon: '👗'),
          SubCategoryModel(id: '1_4',  name: 'Балдар',          nameRu: 'Детская',          icon: '🧒'),
          SubCategoryModel(id: '1_5',  name: 'Мектеп формасы',  nameRu: 'Школьная форма',   icon: '🏫'),
          SubCategoryModel(id: '1_6',  name: 'Кышкы кийим',     nameRu: 'Зимняя одежда',   icon: '🧥'),
          SubCategoryModel(id: '1_7',  name: 'Жайкы кийим',     nameRu: 'Летняя одежда',   icon: '☀️'),
          SubCategoryModel(id: '1_8',  name: 'Спорт кийими',    nameRu: 'Спортивная',       icon: '🏋️'),
          SubCategoryModel(id: '1_9',  name: 'Жумушчу кийим',   nameRu: 'Рабочая одежда',  icon: '🦺'),
          SubCategoryModel(id: '1_10', name: 'Улуттук кийим',   nameRu: 'Национальная',     icon: '🪭'),
          SubCategoryModel(id: '1_11', name: 'Баш кийим',        nameRu: 'Головные уборы',  icon: '🧢'), 
        ],
      ),
      const CategoryModel(
        id: '2', name: 'Бут кийим', nameRu: 'Обувь', icon: '👟', color: 'C77DFF',
        subcategories: [
          SubCategoryModel(id: '2_1', name: 'Баары',          nameRu: 'Все',          icon: '👟'),
          SubCategoryModel(id: '2_2', name: 'Эркектер',       nameRu: 'Мужская',      icon: '👞'),
          SubCategoryModel(id: '2_3', name: 'Аялдар',         nameRu: 'Женская',      icon: '👠'),
          SubCategoryModel(id: '2_4', name: 'Балдар',         nameRu: 'Детская',      icon: '👶'),
          SubCategoryModel(id: '2_5', name: 'Спорт',          nameRu: 'Спортивная',   icon: '⚽'),
          SubCategoryModel(id: '2_6', name: 'Кышкы',          nameRu: 'Зимняя',       icon: '❄️'),
          SubCategoryModel(id: '2_7', name: 'Сандал/Тапочка', nameRu: 'Сандали/Тапки',icon: '🩴'),
          SubCategoryModel(id: '2_8', name: 'Жумушчу',        nameRu: 'Рабочая',      icon: '🔨'),
        ],
      ),
      const CategoryModel(
        id: '3', name: 'Аксессуарлар', nameRu: 'Аксессуары', icon: '👜', color: 'FFD93D',
        subcategories: [
          SubCategoryModel(id: '3_1', name: 'Баары',        nameRu: 'Все',          icon: '👜'),
          SubCategoryModel(id: '3_2', name: 'Сумкалар',     nameRu: 'Сумки',        icon: '🎒'),
          SubCategoryModel(id: '3_3', name: 'Кол саат',     nameRu: 'Часы',         icon: '⌚'),
          SubCategoryModel(id: '3_4', name: 'Көз айнек',    nameRu: 'Очки',         icon: '🕶️'),
          SubCategoryModel(id: '3_5', name: 'Зергерчилик',  nameRu: 'Украшения',    icon: '💍'),
          SubCategoryModel(id: '3_6', name: 'Кемер',        nameRu: 'Ремень',       icon: '👒'),
          SubCategoryModel(id: '3_7', name: 'Жоолук/Шарф',  nameRu: 'Платок/Шарф', icon: '🧣'),
          SubCategoryModel(id: '3_8', name: 'Перчатка',     nameRu: 'Перчатки',     icon: '🧤'),
      
        ],
      ),
      const CategoryModel(
        id: '4', name: 'Электроника', nameRu: 'Электроника', icon: '📱', color: '4895EF',
        subcategories: [
          SubCategoryModel(id: '4_1',  name: 'Баары',          nameRu: 'Все',           icon: '📱'),
          SubCategoryModel(id: '4_2',  name: 'Телефондор',     nameRu: 'Телефоны',      icon: '📲'),
          SubCategoryModel(id: '4_3',  name: 'Ноутбук',        nameRu: 'Ноутбуки',      icon: '💻'),
          SubCategoryModel(id: '4_4',  name: 'Планшет',        nameRu: 'Планшеты',      icon: '📟'),
          SubCategoryModel(id: '4_5',  name: 'Наушник',        nameRu: 'Наушники',      icon: '🎧'),
          SubCategoryModel(id: '4_6',  name: 'Зарядка/Кабель', nameRu: 'Зарядка/Кабель',icon: '🔌'),
          SubCategoryModel(id: '4_7',  name: 'Камера',         nameRu: 'Камера',        icon: '📷'),
          SubCategoryModel(id: '4_8',  name: 'Акылдуу саат',   nameRu: 'Умные часы',    icon: '⌚'),
          SubCategoryModel(id: '4_9',  name: 'Оюн консоли',    nameRu: 'Игровая консоль',icon: '🎮'),
          SubCategoryModel(id: '4_10', name: 'Принтер',        nameRu: 'Принтер',       icon: '🖨️'),
        ],
      ),
      const CategoryModel(
        id: '5', name: 'Үй буюмдар', nameRu: 'Товары для дома', icon: '🏠', color: 'FF922B',
        subcategories: [
          SubCategoryModel(id: '5_1',  name: 'Баары',            nameRu: 'Все',              icon: '🏠'),
          SubCategoryModel(id: '5_2',  name: 'Мебель',           nameRu: 'Мебель',           icon: '🛋️'),
          SubCategoryModel(id: '5_3',  name: 'Жууркан/Жаздык',   nameRu: 'Одеяло/Подушка',  icon: '🛏️'),
          SubCategoryModel(id: '5_4',  name: 'Идиш-аяк',         nameRu: 'Посуда',           icon: '🍽️'),
          SubCategoryModel(id: '5_5',  name: 'Ашкана буюмдары',  nameRu: 'Кухонные товары',  icon: '🥘'),
          SubCategoryModel(id: '5_6',  name: 'Үй жасалгасы',     nameRu: 'Декор',            icon: '🖼️'),
          SubCategoryModel(id: '5_7',  name: 'Жарык буюмдары',   nameRu: 'Освещение',        icon: '💡'),
          SubCategoryModel(id: '5_8',  name: 'Килем/Чий',        nameRu: 'Ковёр/Циновка',   icon: '🪆'),
          SubCategoryModel(id: '5_9',  name: 'Штора/Пардэ',      nameRu: 'Шторы',           icon: '🪟'),
          SubCategoryModel(id: '5_10', name: 'Сантехника',        nameRu: 'Сантехника',       icon: '🚿'),
        ],
      ),
      const CategoryModel(
        id: '6', name: 'Техника', nameRu: 'Бытовая техника', icon: '❄️', color: '52B788',
        subcategories: [
          SubCategoryModel(id: '6_1', name: 'Баары',             nameRu: 'Все',              icon: '❄️'),
          SubCategoryModel(id: '6_2', name: 'Муздаткыч',         nameRu: 'Холодильник',      icon: '🧊'),
          SubCategoryModel(id: '6_3', name: 'Кир жуучу машина',  nameRu: 'Стиральная машина',icon: '🫧'),
          SubCategoryModel(id: '6_4', name: 'Телевизор',         nameRu: 'Телевизор',        icon: '📺'),
          SubCategoryModel(id: '6_5', name: 'Кондиционер',       nameRu: 'Кондиционер',      icon: '🌬️'),
          SubCategoryModel(id: '6_6', name: 'Газ плита',         nameRu: 'Газовая плита',    icon: '🔥'),
          SubCategoryModel(id: '6_7', name: 'Микротолкундуу',    nameRu: 'Микроволновка',    icon: '📡'),
          SubCategoryModel(id: '6_8', name: 'Чаң соргуч',        nameRu: 'Пылесос',          icon: '🌀'),
          SubCategoryModel(id: '6_9', name: 'Утюг',              nameRu: 'Утюг',             icon: '🧺'),
        ],
      ),
      const CategoryModel(
        id: '7', name: 'Спорт', nameRu: 'Спорт', icon: '⚽', color: 'FF6B9D',
        subcategories: [
          SubCategoryModel(id: '7_1',  name: 'Баары',      nameRu: 'Все',        icon: '⚽'),
          SubCategoryModel(id: '7_2',  name: 'Футбол',     nameRu: 'Футбол',     icon: '⚽'),
          SubCategoryModel(id: '7_3',  name: 'Баскетбол',  nameRu: 'Баскетбол',  icon: '🏀'),
          SubCategoryModel(id: '7_4',  name: 'Волейбол',   nameRu: 'Волейбол',   icon: '🏐'),
          SubCategoryModel(id: '7_5',  name: 'Тренажер',   nameRu: 'Тренажёр',   icon: '🏋️'),
          SubCategoryModel(id: '7_6',  name: 'Велосипед',  nameRu: 'Велосипед',  icon: '🚴'),
          SubCategoryModel(id: '7_7',  name: 'Бокс',       nameRu: 'Бокс',       icon: '🥊'),
          SubCategoryModel(id: '7_8',  name: 'Йога/Фитнес',nameRu: 'Йога/Фитнес',icon: '🧘'),
          SubCategoryModel(id: '7_9',  name: 'Сүзүү',      nameRu: 'Плавание',   icon: '🏊'),
          SubCategoryModel(id: '7_10', name: 'Жүгүрүү',    nameRu: 'Бег',        icon: '🏃'),
        ],
      ),
      const CategoryModel(
        id: '8', name: 'Балдар', nameRu: 'Детские товары', icon: '🧸', color: 'FF6B6B',
        subcategories: [
          SubCategoryModel(id: '8_1', name: 'Баары',             nameRu: 'Все',              icon: '🧸'),
          SubCategoryModel(id: '8_2', name: 'Оюнчуктар',         nameRu: 'Игрушки',          icon: '🪀'),
          SubCategoryModel(id: '8_3', name: 'Велосипед',         nameRu: 'Велосипед',        icon: '🚲'),
          SubCategoryModel(id: '8_4', name: 'Коляска',           nameRu: 'Коляска',          icon: '🛒'),
          SubCategoryModel(id: '8_5', name: 'Балдар мебели',     nameRu: 'Детская мебель',   icon: '🪑'),
          SubCategoryModel(id: '8_6', name: 'Мектеп буюмдары',   nameRu: 'Школьные товары',  icon: '📐'),
          SubCategoryModel(id: '8_7', name: 'Балдар китептери',  nameRu: 'Детские книги',    icon: '📖'),
          SubCategoryModel(id: '8_8', name: 'Балдар тамагы',     nameRu: 'Детское питание',  icon: '🍼'),
        ],
      ),
      const CategoryModel(
        id: '9', name: 'Сулуулук', nameRu: 'Красота', icon: '💄', color: 'C77DFF',
        subcategories: [
          SubCategoryModel(id: '9_1', name: 'Баары',            nameRu: 'Все',              icon: '💄'),
          SubCategoryModel(id: '9_2', name: 'Жүз карачу',       nameRu: 'Уход за лицом',    icon: '🧖'),
          SubCategoryModel(id: '9_3', name: 'Чач карачу',       nameRu: 'Уход за волосами', icon: '💇'),
          SubCategoryModel(id: '9_4', name: 'Парфюм',           nameRu: 'Парфюм',           icon: '🌸'),
          SubCategoryModel(id: '9_5', name: 'Макияж',           nameRu: 'Макияж',           icon: '💋'),
          SubCategoryModel(id: '9_6', name: 'Тырмак',           nameRu: 'Ногти',            icon: '💅'),
          SubCategoryModel(id: '9_7', name: 'Массаж буюмдары',  nameRu: 'Массаж',           icon: '💆'),
        ],
      ),
      const CategoryModel(
        id: '10', name: 'Гигиена', nameRu: 'Гигиена', icon: '🧴', color: '4ECDC4',
        subcategories: [
          SubCategoryModel(id: '10_1', name: 'Баары',            nameRu: 'Все',              icon: '🧴'),
          SubCategoryModel(id: '10_2', name: 'Шампунь/Гель',     nameRu: 'Шампунь/Гель',    icon: '🚿'),
          SubCategoryModel(id: '10_3', name: 'Тиш пасталары',    nameRu: 'Зубные пасты',    icon: '🦷'),
          SubCategoryModel(id: '10_4', name: 'Сабын',            nameRu: 'Мыло',             icon: '🧼'),
          SubCategoryModel(id: '10_5', name: 'Дезодорант',       nameRu: 'Дезодорант',       icon: '✨'),
          SubCategoryModel(id: '10_6', name: 'Аялдар гигиенасы', nameRu: 'Женская гигиена', icon: '🌺'),
          SubCategoryModel(id: '10_7', name: 'Балдар гигиенасы', nameRu: 'Детская гигиена', icon: '👶'),
        ],
      ),
      const CategoryModel(
        id: '11', name: 'Азык-түлүк', nameRu: 'Продукты питания', icon: '🛒', color: '52B788',
        subcategories: [
          SubCategoryModel(id: '11_1', name: 'Баары',          nameRu: 'Все',              icon: '🛒'),
          SubCategoryModel(id: '11_2', name: 'Дан азыктары',   nameRu: 'Крупы',            icon: '🌾'),
          SubCategoryModel(id: '11_3', name: 'Консервалар',    nameRu: 'Консервы',         icon: '🥫'),
          SubCategoryModel(id: '11_4', name: 'Майлар/Соустар', nameRu: 'Масла/Соусы',     icon: '🫙'),
          SubCategoryModel(id: '11_5', name: 'Кондитердик',    nameRu: 'Кондитерские',     icon: '🍰'),
          SubCategoryModel(id: '11_6', name: 'Суусундуктар',   nameRu: 'Напитки',          icon: '🥤'),
          SubCategoryModel(id: '11_7', name: 'Чай/Кофе',       nameRu: 'Чай/Кофе',        icon: '☕'),
          SubCategoryModel(id: '11_8', name: 'Наан/Нан',       nameRu: 'Хлеб/Выпечка',    icon: '🍞'),
          SubCategoryModel(id: '11_9', name: 'Жашылчалар',     nameRu: 'Овощи/Фрукты',    icon: '🥦'),
        ],
      ),
      const CategoryModel(
        id: '12', name: 'Автотовар', nameRu: 'Автотовары', icon: '🚗', color: '4895EF',
        subcategories: [
          SubCategoryModel(id: '12_1', name: 'Баары',            nameRu: 'Все',              icon: '🚗'),
          SubCategoryModel(id: '12_2', name: 'Аксессуарлар',     nameRu: 'Аксессуары',      icon: '🪝'),
          SubCategoryModel(id: '12_3', name: 'Автохимия',        nameRu: 'Автохимия',        icon: '🧪'),
          SubCategoryModel(id: '12_4', name: 'Дөңгөлөктөр',     nameRu: 'Шины/Диски',       icon: '🛞'),
          SubCategoryModel(id: '12_5', name: 'Запас бөлүктөр',  nameRu: 'Запчасти',         icon: '⚙️'),
          SubCategoryModel(id: '12_6', name: 'Видеорегистратор', nameRu: 'Видеорегистратор', icon: '📹'),
          SubCategoryModel(id: '12_7', name: 'Автоаудио',        nameRu: 'Автоаудио',        icon: '🔊'),
          SubCategoryModel(id: '12_8', name: 'Автосветтер',      nameRu: 'Автосвет',         icon: '💡'),
        ],
      ),
      const CategoryModel(
        id: '13', name: 'Китеп/Канцтовар', nameRu: 'Книги/Канцтовары', icon: '📚', color: 'F4A261',
        subcategories: [
          SubCategoryModel(id: '13_1', name: 'Баары',            nameRu: 'Все',              icon: '📚'),
          SubCategoryModel(id: '13_2', name: 'Окуу китептери',   nameRu: 'Учебники',         icon: '📖'),
          SubCategoryModel(id: '13_3', name: 'Көркөм адабият',   nameRu: 'Художественная',   icon: '📕'),
          SubCategoryModel(id: '13_4', name: 'Балдар китептери', nameRu: 'Детские книги',    icon: '📗'),
          SubCategoryModel(id: '13_5', name: 'Дептер/Блокнот',   nameRu: 'Тетрадь/Блокнот', icon: '📓'),
          SubCategoryModel(id: '13_6', name: 'Калем/Маркер',     nameRu: 'Ручки/Маркеры',   icon: '✏️'),
          SubCategoryModel(id: '13_7', name: 'Рюкзак/Сумка',     nameRu: 'Рюкзак/Сумка',   icon: '🎒'),
        ],
      ),
      const CategoryModel(
        id: '14', name: 'Кездеме/Тигүү', nameRu: 'Ткани/Шитьё', icon: '🧵', color: 'F4A261',
        subcategories: [
          SubCategoryModel(id: '14_1', name: 'Баары',             nameRu: 'Все',              icon: '🧵'),
          SubCategoryModel(id: '14_2', name: 'Кездеме/Мата',      nameRu: 'Ткань/Материал',  icon: '🪢'),
          SubCategoryModel(id: '14_3', name: 'Жип',               nameRu: 'Нитки',            icon: '🧶'),
          SubCategoryModel(id: '14_4', name: 'Тигүү жабдуулары',  nameRu: 'Швейное оборудование',icon: '🪡'),
          SubCategoryModel(id: '14_5', name: 'Фурнитура',          nameRu: 'Фурнитура',        icon: '🔘'),
          SubCategoryModel(id: '14_6', name: 'Вышивка',            nameRu: 'Вышивка',          icon: '🌼'),
        ],
      ),
      const CategoryModel(
        id: '15', name: 'Куралдар', nameRu: 'Инструменты', icon: '🔧', color: '888888',
        subcategories: [
          SubCategoryModel(id: '15_1', name: 'Баары',              nameRu: 'Все',                  icon: '🔧'),
          SubCategoryModel(id: '15_2', name: 'Электр куралдары',   nameRu: 'Электроинструменты',   icon: '⚡'),
          SubCategoryModel(id: '15_3', name: 'Кол куралдары',      nameRu: 'Ручные инструменты',   icon: '🔨'),
          SubCategoryModel(id: '15_4', name: 'Сантехника',         nameRu: 'Сантехника',           icon: '🚰'),
          SubCategoryModel(id: '15_5', name: 'Курулуш материалы',  nameRu: 'Стройматериалы',       icon: '🧱'),
          SubCategoryModel(id: '15_6', name: 'Краска/Лак',         nameRu: 'Краска/Лак',           icon: '🎨'),
          SubCategoryModel(id: '15_7', name: 'Нурдаткычтар',       nameRu: 'Фонари/Освещение',     icon: '🔦'),
        ],
      ),
      const CategoryModel(
        id: '16', name: 'Оюн/Эглентүү', nameRu: 'Игры/Развлечения', icon: '🎮', color: 'E63946',
        subcategories: [
          SubCategoryModel(id: '16_1', name: 'Баары',              nameRu: 'Все',              icon: '🎮'),
          SubCategoryModel(id: '16_2', name: 'Видеооюндар',        nameRu: 'Видеоигры',        icon: '🕹️'),
          SubCategoryModel(id: '16_3', name: 'Настолка оюндары',   nameRu: 'Настольные игры',  icon: '♟️'),
          SubCategoryModel(id: '16_4', name: 'Пазл',               nameRu: 'Пазл',             icon: '🧩'),
          SubCategoryModel(id: '16_5', name: 'Музыка аспаптары',   nameRu: 'Музыкальные инструменты',icon: '🎸'),
          SubCategoryModel(id: '16_6', name: 'Сүрөт тартуу',       nameRu: 'Рисование',        icon: '🖌️'),
        ],
      ),
      const CategoryModel(
        id: '17', name: 'Багчылык', nameRu: 'Садоводство', icon: '🪴', color: '6BCB77',
        subcategories: [
          SubCategoryModel(id: '17_1', name: 'Баары',               nameRu: 'Все',              icon: '🪴'),
          SubCategoryModel(id: '17_2', name: 'Үй өсүмдүктөрү',     nameRu: 'Комнатные растения',icon: '🌿'),
          SubCategoryModel(id: '17_3', name: 'Багчылык куралдары',  nameRu: 'Садовые инструменты',icon: '🌱'),
          SubCategoryModel(id: '17_4', name: 'Топурак/Жер',         nameRu: 'Грунт/Земля',     icon: '🌍'),
          SubCategoryModel(id: '17_5', name: 'Уруктар',             nameRu: 'Семена',           icon: '🌻'),
          SubCategoryModel(id: '17_6', name: 'Кашпо/Горшок',        nameRu: 'Горшки/Кашпо',    icon: '🏺'),
        ],
      ),
      const CategoryModel(
        id: '18', name: 'Жаныбарлар', nameRu: 'Товары для животных', icon: '🐾', color: 'FF922B',
        subcategories: [
          SubCategoryModel(id: '18_1', name: 'Баары',             nameRu: 'Все',              icon: '🐾'),
          SubCategoryModel(id: '18_2', name: 'Ит буюмдары',       nameRu: 'Для собак',        icon: '🐕'),
          SubCategoryModel(id: '18_3', name: 'Мышык буюмдары',    nameRu: 'Для кошек',        icon: '🐈'),
          SubCategoryModel(id: '18_4', name: 'Жем/Азык',          nameRu: 'Корм/Питание',     icon: '🦴'),
          SubCategoryModel(id: '18_5', name: 'Тор/Клетка',        nameRu: 'Клетки/Вольеры',   icon: '🪹'),
          SubCategoryModel(id: '18_6', name: 'Ветеринардык',       nameRu: 'Ветеринария',       icon: '💊'),
        ],
      ),
    ];
  }
}

class SubCategoryModel {
  final String id;
  final String name;    // кыргызча
  final String nameRu; // орусча
  final String icon;

  const SubCategoryModel({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.icon,
  });

  /// Тилге жараша ат кайтарат
  String localizedName(String langCode) =>
      langCode == 'ru' ? nameRu : name;
}
