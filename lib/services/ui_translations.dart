import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small, code based UI dictionary. Lesson questions and lesson instructions
/// remain in their source data and are intentionally not translated here.
class UiTranslations {
  UiTranslations._();

  static String languageCode = 'en';
  static const _languagePreferenceKey = 'howbuddy_ui_language';

  static void setLanguage(String code) {
    languageCode = const {'en', 'fr', 'es', 'hi', 'ru'}.contains(code)
        ? code
        : 'en';
  }

  static Future<void> loadSavedLanguage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      setLanguage(preferences.getString(_languagePreferenceKey) ?? 'en');
    } catch (_) {
      setLanguage('en');
    }
  }

  static void saveLanguage(String code) {
    setLanguage(code);
    unawaited(_persistLanguage());
  }

  static Future<void> _persistLanguage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_languagePreferenceKey, languageCode);
    } catch (_) {
      // The UI still switches immediately if local persistence is unavailable.
    }
  }

  static String languageName(String code) => switch (code) {
    'fr' => 'Français',
    'es' => 'Español',
    'hi' => 'हिन्दी',
    'ru' => 'Русский',
    _ => 'English',
  };

  static String text(
    BuildContext context,
    String english, {
    Map<String, String> args = const {},
  }) {
    final translated = _strings[english]?[languageCode] ?? english;
    return args.entries.fold(
      translated,
      (value, entry) => value.replaceAll('{${entry.key}}', entry.value),
    );
  }

  static const Map<String, Map<String, String>> _strings = {
    'Create your account': {
      'fr': 'Créez votre compte',
      'es': 'Crea tu cuenta',
      'hi': 'अपना खाता बनाएँ',
      'ru': 'Создайте аккаунт',
    },
    'Join HowBuddy and start your journey!': {
      'fr': 'Rejoignez HowBuddy et commencez votre parcours !',
      'es': '¡Únete a HowBuddy y comienza tu camino!',
      'hi': 'HowBuddy से जुड़ें और अपनी यात्रा शुरू करें!',
      'ru': 'Присоединяйтесь к HowBuddy и начните свой путь!',
    },
    'Your Friendly Guide to How Your Body Works': {
      'fr':
          'Votre guide amical pour comprendre le fonctionnement de votre corps',
      'es': 'Tu guía amigable para entender cómo funciona tu cuerpo',
      'hi':
          'आपका शरीर कैसे काम करता है, यह जानने के लिए आपका दोस्ताना मार्गदर्शक',
      'ru': 'Ваш дружелюбный проводник в мир работы человеческого тела',
    },
    'Full Name': {
      'fr': 'Nom complet',
      'es': 'Nombre completo',
      'hi': 'पूरा नाम',
      'ru': 'Полное имя',
    },
    'Enter your full name.': {
      'fr': 'Saisissez votre nom complet.',
      'es': 'Escribe tu nombre completo.',
      'hi': 'अपना पूरा नाम दर्ज करें।',
      'ru': 'Введите своё полное имя.',
    },
    'Email Address': {
      'fr': 'Adresse e-mail',
      'es': 'Correo electrónico',
      'hi': 'ईमेल पता',
      'ru': 'Электронная почта',
    },
    'Enter a valid email address.': {
      'fr': 'Saisissez une adresse e-mail valide.',
      'es': 'Escribe una dirección de correo válida.',
      'hi': 'मान्य ईमेल पता दर्ज करें।',
      'ru': 'Введите действующий адрес электронной почты.',
    },
    'Confirm Password': {
      'fr': 'Confirmez le mot de passe',
      'es': 'Confirmar contraseña',
      'hi': 'पासवर्ड की पुष्टि करें',
      'ru': 'Подтвердите пароль',
    },
    'Passwords do not match.': {
      'fr': 'Les mots de passe ne correspondent pas.',
      'es': 'Las contraseñas no coinciden.',
      'hi': 'पासवर्ड मेल नहीं खाते।',
      'ru': 'Пароли не совпадают.',
    },
    'Sign up': {
      'fr': 'S’inscrire',
      'es': 'Registrarse',
      'hi': 'साइन अप करें',
      'ru': 'Зарегистрироваться',
    },
    'Sign up with Google': {
      'fr': 'S’inscrire avec Google',
      'es': 'Registrarse con Google',
      'hi': 'Google से साइन अप करें',
      'ru': 'Зарегистрироваться через Google',
    },
    'Sign up with Apple (coming soon)': {
      'fr': 'S’inscrire avec Apple (bientôt)',
      'es': 'Registrarse con Apple (próximamente)',
      'hi': 'Apple से साइन अप करें (जल्द आ रहा है)',
      'ru': 'Регистрация через Apple (скоро)',
    },
    'Already have an account?': {
      'fr': 'Vous avez déjà un compte ?',
      'es': '¿Ya tienes una cuenta?',
      'hi': 'क्या आपका खाता पहले से है?',
      'ru': 'Уже есть аккаунт?',
    },
    'Please complete all fields correctly.': {
      'fr': 'Veuillez remplir correctement tous les champs.',
      'es': 'Completa todos los campos correctamente.',
      'hi': 'कृपया सभी फ़ील्ड सही ढंग से भरें।',
      'ru': 'Заполните все поля правильно.',
    },
    'An account already exists for this email.': {
      'fr': 'Un compte existe déjà pour cette adresse e-mail.',
      'es': 'Ya existe una cuenta con este correo.',
      'hi': 'इस ईमेल के लिए खाता पहले से मौजूद है।',
      'ru': 'Для этой почты уже существует аккаунт.',
    },
    'Social sign up details are invalid.': {
      'fr': 'Les informations d’inscription sont invalides.',
      'es': 'Los datos de registro no son válidos.',
      'hi': 'साइन अप की जानकारी अमान्य है।',
      'ru': 'Данные для регистрации недействительны.',
    },
    'Welcome back!': {
      'fr': 'Bon retour !',
      'es': '¡Qué bueno verte de nuevo!',
      'hi': 'वापसी पर स्वागत है!',
      'ru': 'С возвращением!',
    },
    'Login to continue your journey': {
      'fr': 'Connectez-vous pour continuer votre parcours',
      'es': 'Inicia sesión para continuar tu camino',
      'hi': 'अपनी यात्रा जारी रखने के लिए लॉग इन करें',
      'ru': 'Войдите, чтобы продолжить свой путь',
    },
    'Email or Username': {
      'fr': 'E-mail ou nom d’utilisateur',
      'es': 'Correo o nombre de usuario',
      'hi': 'ईमेल या उपयोगकर्ता नाम',
      'ru': 'Электронная почта или имя пользователя',
    },
    'Enter your email or username.': {
      'fr': 'Saisissez votre e-mail ou nom d’utilisateur.',
      'es': 'Escribe tu correo o nombre de usuario.',
      'hi': 'अपना ईमेल या उपयोगकर्ता नाम दर्ज करें।',
      'ru': 'Введите электронную почту или имя пользователя.',
    },
    'Password': {
      'fr': 'Mot de passe',
      'es': 'Contraseña',
      'hi': 'पासवर्ड',
      'ru': 'Пароль',
    },
    'Password must be at least 8 characters.': {
      'fr': 'Le mot de passe doit contenir au moins 8 caractères.',
      'es': 'La contraseña debe tener al menos 8 caracteres.',
      'hi': 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए।',
      'ru': 'Пароль должен содержать не менее 8 символов.',
    },
    'Show password': {
      'fr': 'Afficher le mot de passe',
      'es': 'Mostrar contraseña',
      'hi': 'पासवर्ड दिखाएँ',
      'ru': 'Показать пароль',
    },
    'Hide password': {
      'fr': 'Masquer le mot de passe',
      'es': 'Ocultar contraseña',
      'hi': 'पासवर्ड छिपाएँ',
      'ru': 'Скрыть пароль',
    },
    'Login': {
      'fr': 'Connexion',
      'es': 'Iniciar sesión',
      'hi': 'लॉग इन',
      'ru': 'Войти',
    },
    'Sign in with Apple (coming soon)': {
      'fr': 'Se connecter avec Apple (bientôt)',
      'es': 'Iniciar sesión con Apple (próximamente)',
      'hi': 'Apple से लॉग इन करें (जल्द आ रहा है)',
      'ru': 'Войти через Apple (скоро)',
    },
    "Don't have an account?": {
      'fr': 'Vous n’avez pas de compte ?',
      'es': '¿No tienes una cuenta?',
      'hi': 'क्या आपका खाता नहीं है?',
      'ru': 'Нет аккаунта?',
    },
    'Sign Up': {
      'fr': 'Créer un compte',
      'es': 'Crear cuenta',
      'hi': 'खाता बनाएँ',
      'ru': 'Создать аккаунт',
    },
    'or': {'fr': 'ou', 'es': 'o', 'hi': 'या', 'ru': 'или'},
    'Sign in with Google': {
      'fr': 'Se connecter avec Google',
      'es': 'Iniciar sesión con Google',
      'hi': 'Google से लॉग इन करें',
      'ru': 'Войти через Google',
    },
    'Could not reach the account server.': {
      'fr': 'Impossible de joindre le serveur de compte.',
      'es': 'No se pudo conectar con el servidor de cuentas.',
      'hi': 'खाता सर्वर से संपर्क नहीं हो सका।',
      'ru': 'Не удалось связаться с сервером аккаунтов.',
    },
    'Invalid email, username, or password.': {
      'fr': 'E-mail, nom d’utilisateur ou mot de passe invalide.',
      'es': 'Correo, nombre de usuario o contraseña incorrectos.',
      'hi': 'ईमेल, उपयोगकर्ता नाम या पासवर्ड गलत है।',
      'ru': 'Неверная почта, имя пользователя или пароль.',
    },
    'Tree': {'fr': 'Arbre', 'es': 'Árbol', 'hi': 'पेड़', 'ru': 'Дерево'},
    'Main Tree': {
      'fr': 'Arbre principal',
      'es': 'Árbol principal',
      'hi': 'मुख्य वृक्ष',
      'ru': 'Главное дерево',
    },
    'Glasses accessory': {
      'fr': 'Accessoire lunettes',
      'es': 'Accesorio de gafas',
      'hi': 'चश्मे का एक्सेसरी',
      'ru': 'Аксессуар: очки',
    },
    'Choose glasses to layer over your buddy.': {
      'fr': 'Choisissez des lunettes à superposer sur votre compagnon.',
      'es': 'Elige unas gafas para poner sobre tu compañero.',
      'hi': 'अपने साथी के ऊपर लगाने के लिए चश्मा चुनें।',
      'ru': 'Выберите очки, которые будут отображаться поверх вашего друга.',
    },
    'No glasses': {
      'fr': 'Sans lunettes',
      'es': 'Sin gafas',
      'hi': 'बिना चश्मे के',
      'ru': 'Без очков',
    },
    'None': {'fr': 'Aucun', 'es': 'Ninguno', 'hi': 'कोई नहीं', 'ru': 'Нет'},
    'Glasses {number}': {
      'fr': 'Lunettes {number}',
      'es': 'Gafas {number}',
      'hi': 'चश्मा {number}',
      'ru': 'Очки {number}',
    },
    'Could not save your glasses.': {
      'fr': 'Impossible d’enregistrer vos lunettes.',
      'es': 'No se pudieron guardar tus gafas.',
      'hi': 'आपका चश्मा सहेजा नहीं जा सका।',
      'ru': 'Не удалось сохранить выбранные очки.',
    },
    'Decorative effects': {
      'fr': 'Effets décoratifs',
      'es': 'Efectos decorativos',
      'hi': 'सजावटी प्रभाव',
      'ru': 'Декоративные эффекты',
    },
    'Add flowers, stars, hearts, and other details.': {
      'fr': 'Ajoutez des fleurs, des étoiles, des cœurs et d’autres détails.',
      'es': 'Añade flores, estrellas, corazones y otros detalles.',
      'hi': 'फूल, तारे, दिल और अन्य सजावट जोड़ें।',
      'ru': 'Добавьте цветы, звёзды, сердечки и другие детали.',
    },
    'No effect': {
      'fr': 'Aucun effet',
      'es': 'Sin efecto',
      'hi': 'कोई प्रभाव नहीं',
      'ru': 'Без эффекта',
    },
    'Effect {number}': {
      'fr': 'Effet {number}',
      'es': 'Efecto {number}',
      'hi': 'प्रभाव {number}',
      'ru': 'Эффект {number}',
    },
    'Could not save your avatar effect.': {
      'fr': 'Impossible d’enregistrer l’effet de votre avatar.',
      'es': 'No se pudo guardar el efecto de tu avatar.',
      'hi': 'आपके अवतार का प्रभाव सहेजा नहीं जा सका।',
      'ru': 'Не удалось сохранить эффект аватара.',
    },
    'Topics': {'fr': 'Sujets', 'es': 'Temas', 'hi': 'विषय', 'ru': 'Темы'},
    'XP': {'fr': 'XP', 'es': 'XP', 'hi': 'XP', 'ru': 'XP'},
    'Profile': {
      'fr': 'Profil',
      'es': 'Perfil',
      'hi': 'प्रोफ़ाइल',
      'ru': 'Профиль',
    },
    'days': {'fr': 'jours', 'es': 'días', 'hi': 'दिन', 'ru': 'дн.'},
    'Your XP': {
      'fr': 'Votre XP',
      'es': 'Tu XP',
      'hi': 'आपका XP',
      'ru': 'Ваш XP',
    },
    '{count} total XP': {
      'fr': '{count} XP au total',
      'es': '{count} XP en total',
      'hi': 'कुल {count} XP',
      'ru': 'Всего {count} XP',
    },
    'Leaderboard': {
      'fr': 'Classement',
      'es': 'Clasificación',
      'hi': 'लीडरबोर्ड',
      'ru': 'Таблица лидеров',
    },
    'This week': {
      'fr': 'Cette semaine',
      'es': 'Esta semana',
      'hi': 'इस सप्ताह',
      'ru': 'На этой неделе',
    },
    'Mon': {'fr': 'Lun', 'es': 'Lun', 'hi': 'सोम', 'ru': 'Пн'},
    'Tue': {'fr': 'Mar', 'es': 'Mar', 'hi': 'मंगल', 'ru': 'Вт'},
    'Wed': {'fr': 'Mer', 'es': 'Mié', 'hi': 'बुध', 'ru': 'Ср'},
    'Thu': {'fr': 'Jeu', 'es': 'Jue', 'hi': 'गुरु', 'ru': 'Чт'},
    'Fri': {'fr': 'Ven', 'es': 'Vie', 'hi': 'शुक्र', 'ru': 'Пт'},
    'Sat': {'fr': 'Sam', 'es': 'Sáb', 'hi': 'शनि', 'ru': 'Сб'},
    'Sun': {'fr': 'Dim', 'es': 'Dom', 'hi': 'रवि', 'ru': 'Вс'},
    'XP earned each day over the last 7 days': {
      'fr': 'XP gagnés chaque jour au cours des 7 derniers jours',
      'es': 'XP obtenidos cada día durante los últimos 7 días',
      'hi': 'पिछले 7 दिनों में हर दिन अर्जित XP',
      'ru': 'XP, заработанные за каждый из последних 7 дней',
    },
    'Could not load your XP. Please check your connection and try again.': {
      'fr':
          'Impossible de charger votre XP. Vérifiez votre connexion et réessayez.',
      'es':
          'No se pudo cargar tu XP. Comprueba la conexión e inténtalo de nuevo.',
      'hi': 'आपका XP लोड नहीं हो सका। कनेक्शन जाँचें और फिर कोशिश करें।',
      'ru':
          'Не удалось загрузить XP. Проверьте подключение и попробуйте снова.',
    },
    ' (you)': {'fr': ' (vous)', 'es': ' (tú)', 'hi': ' (आप)', 'ru': ' (вы)'},
    'Hi, {name}': {
      'fr': 'Bonjour, {name}',
      'es': 'Hola, {name}',
      'hi': 'नमस्ते, {name}',
      'ru': 'Привет, {name}',
    },
    'Language preference': {
      'fr': 'Langue préférée',
      'es': 'Idioma preferido',
      'hi': 'पसंदीदा भाषा',
      'ru': 'Предпочитаемый язык',
    },
    'Age': {'fr': 'Âge', 'es': 'Edad', 'hi': 'उम्र', 'ru': 'Возраст'},
    'Dark mode': {
      'fr': 'Mode sombre',
      'es': 'Modo oscuro',
      'hi': 'डार्क मोड',
      'ru': 'Тёмная тема',
    },
    'On': {'fr': 'Activé', 'es': 'Activado', 'hi': 'चालू', 'ru': 'Вкл.'},
    'Off': {'fr': 'Désactivé', 'es': 'Desactivado', 'hi': 'बंद', 'ru': 'Выкл.'},
    'Customize your buddy': {
      'fr': 'Personnalisez votre compagnon',
      'es': 'Personaliza a tu compañero',
      'hi': 'अपने साथी को अनुकूलित करें',
      'ru': 'Настройте своего друга',
    },
    'Choose a color palette. Your eyes, mouth, and background stay the same.': {
      'fr':
          'Choisissez une palette de couleurs. Les yeux, la bouche et le fond restent identiques.',
      'es':
          'Elige una paleta de colores. Los ojos, la boca y el fondo no cambian.',
      'hi': 'रंग पैलेट चुनें। आँखें, मुँह और पृष्ठभूमि वही रहेंगे।',
      'ru': 'Выберите палитру. Глаза, рот и фон останутся прежними.',
    },
    'Logout': {
      'fr': 'Déconnexion',
      'es': 'Cerrar sesión',
      'hi': 'लॉग आउट',
      'ru': 'Выйти',
    },
    'Could not save your avatar colors.': {
      'fr': 'Impossible d’enregistrer les couleurs de votre avatar.',
      'es': 'No se pudieron guardar los colores del avatar.',
      'hi': 'अवतार के रंग सेव नहीं हो सके।',
      'ru': 'Не удалось сохранить цвета аватара.',
    },
    'Could not save your preferences.': {
      'fr': 'Impossible d’enregistrer vos préférences.',
      'es': 'No se pudieron guardar tus preferencias.',
      'hi': 'आपकी प्राथमिकताएँ सेव नहीं हो सकीं।',
      'ru': 'Не удалось сохранить настройки.',
    },
    'Hearts': {'fr': 'Cœurs', 'es': 'Corazones', 'hi': 'दिल', 'ru': 'Сердца'},
    '{count} of 5 hearts': {
      'fr': '{count} sur 5 cœurs',
      'es': '{count} de 5 corazones',
      'hi': '5 में से {count} दिल',
      'ru': '{count} из 5 сердец',
    },
    'Starting a lesson uses one heart.': {
      'fr': 'Commencer une leçon coûte un cœur.',
      'es': 'Empezar una lección consume un corazón.',
      'hi': 'पाठ शुरू करने पर एक दिल खर्च होता है।',
      'ru': 'Начало урока расходует одно сердце.',
    },
    'A heart will recharge in 3:00:00': {
      'fr': 'Un cœur se recharge dans 3:00:00',
      'es': 'Un corazón se recarga en 3:00:00',
      'hi': 'एक दिल 3:00:00 में फिर मिलेगा',
      'ru': 'Сердце восстановится через 3:00:00',
    },
    'Next heart in {time}': {
      'fr': 'Prochain cœur dans {time}',
      'es': 'Próximo corazón en {time}',
      'hi': 'अगला दिल {time} में',
      'ru': 'Следующее сердце через {time}',
    },
    'Hearts are full': {
      'fr': 'Tous les cœurs sont pleins',
      'es': 'Tienes todos los corazones',
      'hi': 'सभी दिल भर गए हैं',
      'ru': 'Сердца полны',
    },
    'Watch ad - +1 heart': {
      'fr': 'Voir une pub - +1 cœur',
      'es': 'Ver anuncio - +1 corazón',
      'hi': 'विज्ञापन देखें - +1 दिल',
      'ru': 'Посмотреть рекламу — +1 сердце',
    },
    'SIMULATED AD - WEB DEMO. No real advertisement is shown.': {
      'fr': 'PUBLICITÉ SIMULÉE - DÉMO WEB. Aucune vraie publicité.',
      'es': 'ANUNCIO SIMULADO - DEMO WEB. No se muestra publicidad real.',
      'hi': 'सिम्युलेटेड विज्ञापन - वेब डेमो। असली विज्ञापन नहीं दिखाया जाता।',
      'ru': 'ИМИТАЦИЯ РЕКЛАМЫ — ВЕБ-ДЕМО. Настоящая реклама не показывается.',
    },
    'TEST AD - ADMOB. Test ads do not generate revenue.': {
      'fr': 'PUB DE TEST - ADMOB. Les pubs de test ne génèrent aucun revenu.',
      'es': 'ANUNCIO DE PRUEBA - ADMOB. No genera ingresos.',
      'hi': 'टेस्ट विज्ञापन - ADMOB। इससे कमाई नहीं होती।',
      'ru': 'ТЕСТОВАЯ РЕКЛАМА — ADMOB. Дохода не приносит.',
    },
    'Could not restore a heart. Please try again.': {
      'fr': 'Impossible de récupérer un cœur. Réessayez.',
      'es': 'No se pudo recuperar un corazón. Inténtalo de nuevo.',
      'hi': 'दिल वापस नहीं मिला। फिर कोशिश करें।',
      'ru': 'Не удалось восстановить сердце. Попробуйте снова.',
    },
    'Emerald shop': {
      'fr': 'Boutique d’émeraudes',
      'es': 'Tienda de esmeraldas',
      'hi': 'पन्ना दुकान',
      'ru': 'Магазин изумрудов',
    },
    '{count} emeralds': {
      'fr': '{count} émeraudes',
      'es': '{count} esmeraldas',
      'hi': '{count} पन्ने',
      'ru': '{count} изумрудов',
    },
    'No active boost': {
      'fr': 'Aucun bonus actif',
      'es': 'No hay potenciador activo',
      'hi': 'कोई बूस्ट सक्रिय नहीं',
      'ru': 'Бонус не активен',
    },
    '2x XP active - {time} left': {
      'fr': 'XP x2 actif - encore {time}',
      'es': 'XP x2 activo - quedan {time}',
      'hi': '2x XP चालू - {time} शेष',
      'ru': 'XP x2 активно — осталось {time}',
    },
    'Double your lesson XP': {
      'fr': 'Doublez votre XP de leçon',
      'es': 'Duplica el XP de tus lecciones',
      'hi': 'अपने पाठ का XP दोगुना करें',
      'ru': 'Удвойте XP за уроки',
    },
    '{minutes} minute - 2x XP': {
      'fr': '{minutes} minute - XP x2',
      'es': '{minutes} minuto - XP x2',
      'hi': '{minutes} मिनट - 2x XP',
      'ru': '{minutes} минута — XP x2',
    },
    '{minutes} minutes - 2x XP': {
      'fr': '{minutes} minutes - XP x2',
      'es': '{minutes} minutos - XP x2',
      'hi': '{minutes} मिनट - 2x XP',
      'ru': '{minutes} минут — XP x2',
    },
    'Price: {price}': {
      'fr': 'Prix : {price}',
      'es': 'Precio: {price}',
      'hi': 'कीमत: {price}',
      'ru': 'Цена: {price}',
    },
    'Watch ad - +25 emeralds': {
      'fr': 'Voir une pub - +25 émeraudes',
      'es': 'Ver anuncio - +25 esmeraldas',
      'hi': 'विज्ञापन देखें - +25 पन्ने',
      'ru': 'Посмотреть рекламу — +25 изумрудов',
    },
    'Could not buy the XP boost. Please try again.': {
      'fr': 'Impossible d’acheter le bonus XP. Réessayez.',
      'es': 'No se pudo comprar el potenciador de XP. Inténtalo de nuevo.',
      'hi': 'XP बूस्ट नहीं खरीदा जा सका। फिर कोशिश करें।',
      'ru': 'Не удалось купить бонус XP. Попробуйте снова.',
    },
    'Could not add emeralds. Please try again.': {
      'fr': 'Impossible d’ajouter des émeraudes. Réessayez.',
      'es': 'No se pudieron añadir esmeraldas. Inténtalo de nuevo.',
      'hi': 'पन्ने नहीं जुड़ सके। फिर कोशिश करें।',
      'ru': 'Не удалось добавить изумруды. Попробуйте снова.',
    },
    'Study streak': {
      'fr': 'Série d’apprentissage',
      'es': 'Racha de estudio',
      'hi': 'पढ़ाई की लगातार अवधि',
      'ru': 'Учебная серия',
    },
    '{count} day streak': {
      'fr': 'Série de {count} jours',
      'es': 'Racha de {count} días',
      'hi': '{count} दिन की स्ट्रीक',
      'ru': 'Серия: {count} дн.',
    },
    'Previous month': {
      'fr': 'Mois précédent',
      'es': 'Mes anterior',
      'hi': 'पिछला महीना',
      'ru': 'Предыдущий месяц',
    },
    'Next month': {
      'fr': 'Mois suivant',
      'es': 'Mes siguiente',
      'hi': 'अगला महीना',
      'ru': 'Следующий месяц',
    },
    'Days you completed a lesson are highlighted.': {
      'fr': 'Les jours où vous avez terminé une leçon sont surlignés.',
      'es': 'Se resaltan los días en que completaste una lección.',
      'hi': 'जिन दिनों आपने पाठ पूरा किया, वे हाइलाइट हैं।',
      'ru': 'Дни, когда вы завершили урок, выделены.',
    },
    'January': {'fr': 'janvier', 'es': 'enero', 'hi': 'जनवरी', 'ru': 'января'},
    'February': {
      'fr': 'février',
      'es': 'febrero',
      'hi': 'फ़रवरी',
      'ru': 'февраля',
    },
    'March': {'fr': 'mars', 'es': 'marzo', 'hi': 'मार्च', 'ru': 'марта'},
    'April': {'fr': 'avril', 'es': 'abril', 'hi': 'अप्रैल', 'ru': 'апреля'},
    'May': {'fr': 'mai', 'es': 'mayo', 'hi': 'मई', 'ru': 'мая'},
    'June': {'fr': 'juin', 'es': 'junio', 'hi': 'जून', 'ru': 'июня'},
    'July': {'fr': 'juillet', 'es': 'julio', 'hi': 'जुलाई', 'ru': 'июля'},
    'August': {'fr': 'août', 'es': 'agosto', 'hi': 'अगस्त', 'ru': 'августа'},
    'September': {
      'fr': 'septembre',
      'es': 'septiembre',
      'hi': 'सितंबर',
      'ru': 'сентября',
    },
    'October': {
      'fr': 'octobre',
      'es': 'octubre',
      'hi': 'अक्टूबर',
      'ru': 'октября',
    },
    'November': {
      'fr': 'novembre',
      'es': 'noviembre',
      'hi': 'नवंबर',
      'ru': 'ноября',
    },
    'December': {
      'fr': 'décembre',
      'es': 'diciembre',
      'hi': 'दिसंबर',
      'ru': 'декабря',
    },
    'Could not load notepad tree.': {
      'fr': 'Impossible de charger l’arbre des sujets.',
      'es': 'No se pudo cargar el árbol de temas.',
      'hi': 'विषयों का ट्री लोड नहीं हो सका।',
      'ru': 'Не удалось загрузить дерево тем.',
    },
    'Where do we want to start?': {
      'fr': 'Par où voulez-vous commencer ?',
      'es': '¿Por dónde quieres empezar?',
      'hi': 'हम कहाँ से शुरू करें?',
      'ru': 'С чего начнём?',
    },
    'Could not load questions.': {
      'fr': 'Impossible de charger les questions.',
      'es': 'No se pudieron cargar las preguntas.',
      'hi': 'प्रश्न लोड नहीं हो सके।',
      'ru': 'Не удалось загрузить вопросы.',
    },
    'Skip to the main tree': {
      'fr': 'Passer à l’arbre principal',
      'es': 'Ir al árbol principal',
      'hi': 'मुख्य ट्री पर जाएँ',
      'ru': 'Перейти к главному дереву',
    },
    'Could not save your preferences. Please try again.': {
      'fr': 'Impossible d’enregistrer vos préférences. Réessayez.',
      'es': 'No se pudieron guardar tus preferencias. Inténtalo de nuevo.',
      'hi': 'आपकी प्राथमिकताएँ सेव नहीं हो सकीं। फिर कोशिश करें।',
      'ru': 'Не удалось сохранить настройки. Попробуйте снова.',
    },
    'Please sign in again.': {
      'fr': 'Veuillez vous reconnecter.',
      'es': 'Vuelve a iniciar sesión.',
      'hi': 'कृपया फिर से साइन इन करें।',
      'ru': 'Войдите в аккаунт снова.',
    },
    'Choose a supported language.': {
      'fr': 'Choisissez une langue prise en charge.',
      'es': 'Elige un idioma disponible.',
      'hi': 'समर्थित भाषा चुनें।',
      'ru': 'Выберите поддерживаемый язык.',
    },
    'Choose an age between 1 and 120.': {
      'fr': 'Choisissez un âge entre 1 et 120 ans.',
      'es': 'Elige una edad entre 1 y 120 años.',
      'hi': '1 से 120 के बीच उम्र चुनें।',
      'ru': 'Укажите возраст от 1 до 120 лет.',
    },
    'A couple of details': {
      'fr': 'Quelques détails',
      'es': 'Un par de detalles',
      'hi': 'कुछ जानकारी',
      'ru': 'Пара деталей',
    },
    'Choose your preferred language and age.': {
      'fr': 'Choisissez votre langue préférée et votre âge.',
      'es': 'Elige tu idioma preferido y tu edad.',
      'hi': 'अपनी पसंदीदा भाषा और उम्र चुनें।',
      'ru': 'Выберите язык и укажите возраст.',
    },
    'Continue': {
      'fr': 'Continuer',
      'es': 'Continuar',
      'hi': 'जारी रखें',
      'ru': 'Продолжить',
    },
    '{count} lessons': {
      'fr': '{count} leçons',
      'es': '{count} lecciones',
      'hi': '{count} पाठ',
      'ru': '{count} уроков',
    },
    '{hours}h {minutes}m {seconds}s': {
      'fr': '{hours} h {minutes} min {seconds} s',
      'es': '{hours} h {minutes} min {seconds} s',
      'hi': '{hours} घं {minutes} मि {seconds} से',
      'ru': '{hours} ч {minutes} мин {seconds} с',
    },
    '{minutes}m {seconds}s': {
      'fr': '{minutes} min {seconds} s',
      'es': '{minutes} min {seconds} s',
      'hi': '{minutes} मि {seconds} से',
      'ru': '{minutes} мин {seconds} с',
    },
    'Original': {
      'fr': 'Original',
      'es': 'Original',
      'hi': 'मूल',
      'ru': 'Оригинал',
    },
    'Palette {number}': {
      'fr': 'Palette {number}',
      'es': 'Paleta {number}',
      'hi': 'पैलेट {number}',
      'ru': 'Палитра {number}',
    },
    '{name} avatar colors': {
      'fr': 'Couleurs d’avatar : {name}',
      'es': 'Colores del avatar: {name}',
      'hi': 'अवतार के रंग: {name}',
      'ru': 'Цвета аватара: {name}',
    },
  };
}

String uiText(
  BuildContext context,
  String english, {
  Map<String, String> args = const {},
}) => UiTranslations.text(context, english, args: args);
