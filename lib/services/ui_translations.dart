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
    'Bobo is locked': {
      'fr': 'Bobo est verrouillé',
      'es': 'Bobo está bloqueado',
      'hi': '\u092c\u094b\u092c\u094b \u0932\u0949\u0915 \u0939\u0948',
      'ru':
          '\u0411\u043e\u0431\u043e \u0437\u0430\u0431\u043b\u043e\u043a\u0438\u0440\u043e\u0432\u0430\u043d',
    },
    'Try answering first, or get a hint! \u{1F49C}': {
      'fr': 'Essaie de répondre d’abord ou demande un indice ! \u{1F49C}',
      'es': '¡Intenta responder primero o pide una pista! \u{1F49C}',
      'hi':
          '\u092a\u0939\u0932\u0947 \u091c\u0935\u093e\u092c \u0926\u0947\u0928\u0947 \u0915\u0940 \u0915\u094b\u0936\u093f\u0936 \u0915\u0930\u094b, \u092f\u093e \u0938\u0902\u0915\u0947\u0924 \u092e\u093e\u0902\u0917\u094b! \u{1F49C}',
      'ru':
          '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043f\u043e\u043f\u0440\u043e\u0431\u0443\u0439 \u043e\u0442\u0432\u0435\u0442\u0438\u0442\u044c \u0438\u043b\u0438 \u043f\u043e\u043f\u0440\u043e\u0441\u0438 \u043f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0443! \u{1F49C}',
    },
    'Get a hint': {
      'fr': 'Obtenir un indice',
      'es': 'Obtener una pista',
      'hi': '\u0938\u0902\u0915\u0947\u0924 \u092a\u093e\u090f\u0902',
      'ru':
          '\u041f\u043e\u043b\u0443\u0447\u0438\u0442\u044c \u043f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0443',
    },
    "Bobo's hint": {
      'fr': 'Indice de Bobo',
      'es': 'Pista de Bobo',
      'hi':
          '\u092c\u094b\u092c\u094b \u0915\u093e \u0938\u0902\u0915\u0947\u0924',
      'ru':
          '\u041f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0430 \u0411\u043e\u0431\u043e',
    },
    'Back to lesson': {
      'fr': 'Retour à la leçon',
      'es': 'Volver a la lección',
      'hi':
          '\u092a\u093e\u0920 \u092a\u0930 \u0935\u093e\u092a\u0938 \u091c\u093e\u090f\u0902',
      'ru':
          '\u0412\u0435\u0440\u043d\u0443\u0442\u044c\u0441\u044f \u043a \u0443\u0440\u043e\u043a\u0443',
    },
    'Bobo is thinking...': {
      'fr': 'Bobo réfléchit...',
      'es': 'Bobo está pensando...',
      'hi':
          '\u092c\u094b\u092c\u094b \u0938\u094b\u091a \u0930\u0939\u093e \u0939\u0948...',
      'ru': '\u0411\u043e\u0431\u043e \u0434\u0443\u043c\u0430\u0435\u0442...',
    },
    'Could not save this answer. Check your connection and try again.': {
      'fr':
          'Impossible d’enregistrer cette réponse. Vérifie ta connexion et réessaie.',
      'es':
          'No se pudo guardar la respuesta. Comprueba tu conexión e inténtalo de nuevo.',
      'hi':
          '\u0907\u0938 \u091c\u0935\u093e\u092c \u0915\u094b \u0938\u0939\u0947\u091c\u093e \u0928\u0939\u0940\u0902 \u091c\u093e \u0938\u0915\u093e\u0964 \u0915\u0928\u0947\u0915\u094d\u0936\u0928 \u091c\u093e\u0902\u091a\u0947\u0902 \u0914\u0930 \u092b\u093f\u0930 \u0915\u094b\u0936\u093f\u0936 \u0915\u0930\u0947\u0902\u0964',
      'ru':
          '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u043e\u0442\u0432\u0435\u0442. \u041f\u0440\u043e\u0432\u0435\u0440\u044c \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0435 \u0438 \u043f\u043e\u043f\u0440\u043e\u0431\u0443\u0439 \u0441\u043d\u043e\u0432\u0430.',
    },
    'Bobo could not get a hint right now. Please try again.': {
      'fr': 'Bobo ne peut pas donner d’indice maintenant. Réessaie.',
      'es': 'Bobo no puede dar una pista ahora. Inténtalo de nuevo.',
      'hi':
          '\u092c\u094b\u092c\u094b \u0905\u092d\u0940 \u0938\u0902\u0915\u0947\u0924 \u0928\u0939\u0940\u0902 \u0926\u0947 \u0938\u0915\u0924\u093e\u0964 \u092b\u093f\u0930 \u0938\u0947 \u0915\u094b\u0936\u093f\u0936 \u0915\u0930\u0947\u0902\u0964',
      'ru':
          '\u0411\u043e\u0431\u043e \u043f\u043e\u043a\u0430 \u043d\u0435 \u043c\u043e\u0436\u0435\u0442 \u0434\u0430\u0442\u044c \u043f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0443. \u041f\u043e\u043f\u0440\u043e\u0431\u0443\u0439 \u0435\u0449\u0451 \u0440\u0430\u0437.',
    },
    'Ask Bobo': {
      'fr': 'Demander à Bobo',
      'es': 'Pregúntale a Bobo',
      'hi':
          '\u092c\u094b\u092c\u094b \u0938\u0947 \u092a\u0942\u091b\u0947\u0902',
      'ru':
          '\u0421\u043f\u0440\u043e\u0441\u0438\u0442\u044c \u0411\u043e\u0431\u043e',
    },
    'Your biology study buddy': {
      'fr': 'Ton compagnon pour apprendre la biologie',
      'es': 'Tu compa\u00f1ero para aprender biolog\u00eda',
      'hi':
          '\u0924\u0941\u092e\u094d\u0939\u093e\u0930\u093e \u092c\u093e\u092f\u094b\u0932\u0949\u091c\u0940 \u0938\u0940\u0916\u0928\u0947 \u0915\u093e \u0938\u093e\u0925\u0940',
      'ru':
          '\u0422\u0432\u043e\u0439 \u043f\u043e\u043c\u043e\u0449\u043d\u0438\u043a \u0432 \u0438\u0437\u0443\u0447\u0435\u043d\u0438\u0438 \u0431\u0438\u043e\u043b\u043e\u0433\u0438\u0438',
    },
    "Hi! I'm Bobo. Ask me about the biology in this lesson, and we'll work through it together.": {
      'fr':
          'Salut ! Je suis Bobo. Pose-moi tes questions sur la biologie de cette leçon, et nous allons la comprendre ensemble.',
      'es':
          '\u00a1Hola! Soy Bobo. Preg\u00fantame sobre la biolog\u00eda de esta lecci\u00f3n y la entenderemos juntos.',
      'hi':
          '\u0928\u092e\u0938\u094d\u0924\u0947! \u092e\u0948\u0902 \u092c\u094b\u092c\u094b \u0939\u0942\u0901\u0964 \u0907\u0938 \u092a\u093e\u0920 \u0915\u0940 \u092c\u093e\u092f\u094b\u0932\u0949\u091c\u0940 \u0915\u0947 \u092c\u093e\u0930\u0947 \u092e\u0947\u0902 \u092a\u0942\u091b\u094b, \u0914\u0930 \u0939\u092e \u092e\u093f\u0932\u0915\u0930 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964',
      'ru':
          '\u041f\u0440\u0438\u0432\u0435\u0442! \u042f \u0411\u043e\u0431\u043e. \u0421\u043f\u0440\u0430\u0448\u0438\u0432\u0430\u0439 \u043c\u0435\u043d\u044f \u043e \u0431\u0438\u043e\u043b\u043e\u0433\u0438\u0438 \u0432 \u044d\u0442\u043e\u043c \u0443\u0440\u043e\u043a\u0435, \u0438 \u043c\u044b \u0440\u0430\u0437\u0431\u0435\u0440\u0451\u043c\u0441\u044f \u0432\u043c\u0435\u0441\u0442\u0435.',
    },
    "Bobo's AI chat isn't connected yet. We'll connect it securely through the HowBuddy server in the next step.": {
      'fr':
          'Le chat IA de Bobo n’est pas encore connecté. Nous le relierons de façon sécurisée au serveur HowBuddy à la prochaine étape.',
      'es':
          'El chat de IA de Bobo aún no está conectado. Lo conectaremos de forma segura al servidor de HowBuddy en el siguiente paso.',
      'hi':
          '\u092c\u094b\u092c\u094b \u0915\u0940 AI \u091a\u0948\u091f \u0905\u092d\u0940 \u091c\u0941\u0921\u093c\u0940 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964 \u0905\u0917\u0932\u0947 \u0915\u0926\u092e \u092e\u0947\u0902 \u0939\u092e \u0907\u0938\u0947 HowBuddy \u0938\u0930\u094d\u0935\u0930 \u0938\u0947 \u0938\u0941\u0930\u0915\u094d\u0937\u093f\u0924 \u0924\u0930\u0940\u0915\u0947 \u0938\u0947 \u091c\u094b\u0921\u093c\u0947\u0902\u0917\u0947\u0964',
      'ru':
          '\u0427\u0430\u0442 \u0441 \u0411\u043e\u0431\u043e \u043f\u043e\u043a\u0430 \u043d\u0435 \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0451\u043d. \u041d\u0430 \u0441\u043b\u0435\u0434\u0443\u044e\u0449\u0435\u043c \u044d\u0442\u0430\u043f\u0435 \u043c\u044b \u0431\u0435\u0437\u043e\u043f\u0430\u0441\u043d\u043e \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0438\u043c \u0435\u0433\u043e \u0447\u0435\u0440\u0435\u0437 \u0441\u0435\u0440\u0432\u0435\u0440 HowBuddy.',
    },
    'Chat will be available soon': {
      'fr': 'Le chat sera bientôt disponible',
      'es': 'El chat estará disponible pronto',
      'hi':
          '\u091a\u0948\u091f \u091c\u0932\u094d\u0926 \u0909\u092a\u0932\u092c\u094d\u0927 \u0939\u094b\u0917\u0940',
      'ru':
          '\u0427\u0430\u0442 \u0441\u043a\u043e\u0440\u043e \u0431\u0443\u0434\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d',
    },
    'Send message': {
      'fr': 'Envoyer le message',
      'es': 'Enviar mensaje',
      'hi': '\u0938\u0902\u0926\u0947\u0936 \u092d\u0947\u091c\u0947\u0902',
      'ru':
          '\u041e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435',
    },
    'Ask Bobo for a hint or explanation': {
      'fr': 'Demander un indice ou une explication à Bobo',
      'es': 'Pedir una pista o explicación a Bobo',
      'hi':
          '\u092c\u094b\u092c\u094b \u0938\u0947 \u0938\u0902\u0915\u0947\u0924 \u092f\u093e \u0935\u094d\u092f\u093e\u0916\u094d\u092f\u093e \u092e\u093e\u0902\u0917\u0947\u0902',
      'ru':
          '\u041f\u043e\u043f\u0440\u043e\u0441\u0438\u0442\u0435 \u0443 \u0411\u043e\u0431\u043e \u043f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0443 \u0438\u043b\u0438 \u043e\u0431\u044a\u044f\u0441\u043d\u0435\u043d\u0438\u0435',
    },
    'Give me a hint': {
      'fr': 'Donne-moi un indice',
      'es': 'Dame una pista',
      'hi':
          '\u092e\u0941\u091d\u0947 \u090f\u0915 \u0938\u0902\u0915\u0947\u0924 \u0926\u094b',
      'ru':
          '\u0414\u0430\u0439 \u043c\u043d\u0435 \u043f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0443',
    },
    'Ask me a guiding question': {
      'fr': 'Pose-moi une question pour me guider',
      'es': 'Hazme una pregunta que me guíe',
      'hi':
          '\u092e\u0941\u091d\u0947 \u0930\u093e\u0939 \u0926\u093f\u0916\u093e\u0928\u0947 \u0935\u093e\u0932\u093e \u0938\u0935\u093e\u0932 \u092a\u0942\u091b\u094b',
      'ru':
          '\u0417\u0430\u0434\u0430\u0439 \u043c\u043d\u0435 \u043d\u0430\u0432\u043e\u0434\u044f\u0449\u0438\u0439 \u0432\u043e\u043f\u0440\u043e\u0441',
    },
    'Explain this more simply': {
      'fr': 'Explique plus simplement',
      'es': 'Explícalo más sencillo',
      'hi':
          '\u0907\u0938\u0947 \u0914\u0930 \u0906\u0938\u093e\u0928 \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u093e\u0913',
      'ru':
          '\u041e\u0431\u044a\u044f\u0441\u043d\u0438 \u043f\u0440\u043e\u0449\u0435',
    },
    "I'm completely lost": {
      'fr': 'Je suis complètement perdu',
      'es': 'Estoy completamente perdido',
      'hi':
          '\u092e\u0948\u0902 \u092c\u093f\u0932\u094d\u0915\u0941\u0932 \u092d\u091f\u0915 \u0917\u092f\u093e \u0939\u0942\u0901',
      'ru':
          '\u042f \u0441\u043e\u0432\u0441\u0435\u043c \u0437\u0430\u043f\u0443\u0442\u0430\u043b\u0441\u044f',
    },
    'Why was my answer wrong?': {
      'fr': 'Pourquoi ma réponse était-elle fausse ?',
      'es': '¿Por qué mi respuesta fue incorrecta?',
      'hi':
          '\u092e\u0947\u0930\u093e \u0909\u0924\u094d\u0924\u0930 \u0917\u0932\u0924 \u0915\u094d\u092f\u094b\u0902 \u0925\u093e?',
      'ru':
          '\u041f\u043e\u0447\u0435\u043c\u0443 \u043c\u043e\u0439 \u043e\u0442\u0432\u0435\u0442 \u0431\u044b\u043b \u043d\u0435\u0432\u0435\u0440\u043d\u044b\u043c?',
    },
    'Help me understand': {
      'fr': 'Aide-moi à comprendre',
      'es': 'Ayúdame a entender',
      'hi':
          '\u092e\u0941\u091d\u0947 \u0938\u092e\u091d\u0928\u0947 \u092e\u0947\u0902 \u092e\u0926\u0926 \u0915\u0930\u094b',
      'ru':
          '\u041f\u043e\u043c\u043e\u0433\u0438 \u043c\u043d\u0435 \u0440\u0430\u0437\u043e\u0431\u0440\u0430\u0442\u044c\u0441\u044f',
    },
    'Try another explanation': {
      'fr': 'Essaie une autre explication',
      'es': 'Prueba otra explicación',
      'hi':
          '\u0915\u094b\u0908 \u0914\u0930 \u0924\u0930\u0940\u0915\u093e \u0938\u092e\u091d\u093e\u0913',
      'ru':
          '\u041f\u043e\u043f\u0440\u043e\u0431\u0443\u0439 \u0434\u0440\u0443\u0433\u043e\u0435 \u043e\u0431\u044a\u044f\u0441\u043d\u0435\u043d\u0438\u0435',
    },
    'Explain this': {
      'fr': 'Explique ceci',
      'es': 'Explica esto',
      'hi': '\u0907\u0938\u0947 \u0938\u092e\u091d\u093e\u0913',
      'ru': '\u041e\u0431\u044a\u044f\u0441\u043d\u0438 \u044d\u0442\u043e',
    },
    'Give me an example': {
      'fr': 'Donne-moi un exemple',
      'es': 'Dame un ejemplo',
      'hi':
          '\u092e\u0941\u091d\u0947 \u090f\u0915 \u0909\u0926\u093e\u0939\u0930\u0923 \u0926\u094b',
      'ru':
          '\u041f\u0440\u0438\u0432\u0435\u0434\u0438 \u043f\u0440\u0438\u043c\u0435\u0440',
    },
    'Go deeper': {
      'fr': 'Approfondis',
      'es': 'Profundiza',
      'hi':
          '\u0914\u0930 \u0917\u0939\u0930\u093e\u0908 \u0938\u0947 \u0938\u092e\u091d\u093e\u0913',
      'ru':
          '\u0420\u0430\u0437\u0431\u0435\u0440\u0438 \u043f\u043e\u0434\u0440\u043e\u0431\u043d\u0435\u0435',
    },
    'Quiz me': {
      'fr': 'Fais-moi un quiz',
      'es': 'Hazme una pregunta',
      'hi':
          '\u041c\u0435\u0440\u0430 \u091b\u094b\u091f\u093e \u0915\u094d\u0935\u093f\u091c\u093c \u0932\u094b',
      'ru':
          '\u0417\u0430\u0434\u0430\u0439 \u043c\u043d\u0435 \u0432\u043e\u043f\u0440\u043e\u0441',
    },
    'Bobo is thinking…': {
      'fr': 'Bobo réfléchit…',
      'es': 'Bobo está pensando…',
      'hi':
          '\u092c\u094b\u092c\u094b \u0938\u094b\u091a \u0930\u0939\u093e \u0939\u0948…',
      'ru': '\u0411\u043e\u0431\u043e \u0434\u0443\u043c\u0430\u0435\u0442…',
    },
    'Lesson: {title}': {
      'fr': 'Leçon : {title}',
      'es': 'Lección: {title}',
      'hi': '\u092a\u093e\u0920: {title}',
      'ru': '\u0423\u0440\u043e\u043a: {title}',
    },
    'Exercise {number}': {
      'fr': 'Exercice {number}',
      'es': 'Ejercicio {number}',
      'hi': '\u0905\u092d\u094d\u092f\u093e\u0938 {number}',
      'ru':
          '\u0423\u043f\u0440\u0430\u0436\u043d\u0435\u043d\u0438\u0435 {number}',
    },
    'Clear conversation': {
      'fr': 'Effacer la conversation',
      'es': 'Borrar conversación',
      'hi':
          '\u092c\u093e\u0924\u091a\u0940\u0924 \u0939\u091f\u093e\u090f\u0902',
      'ru':
          '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u0434\u0438\u0430\u043b\u043e\u0433',
    },
    'Clear conversation?': {
      'fr': 'Effacer la conversation ? ',
      'es': '¿Borrar la conversación?',
      'hi':
          '\u0915\u094d\u092f\u093e \u092c\u093e\u0924\u091a\u0940\u0924 \u0939\u091f\u093e\u090f\u0902?',
      'ru':
          '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u0434\u0438\u0430\u043b\u043e\u0433?',
    },
    'This permanently deletes this Bobo chat.': {
      'fr':
          'Cette action supprimera définitivement cette conversation avec Bobo.',
      'es': 'Esto eliminará permanentemente este chat con Bobo.',
      'hi':
          '\u092f\u0939 \u092c\u094b\u092c\u094b \u0915\u0940 \u092c\u093e\u0924\u091a\u0940\u0924 \u0938\u094d\u0925\u093e\u092f\u0940 \u0930\u0942\u092a \u0938\u0947 \u0939\u091f\u093e \u0926\u0947\u0917\u093e\u0964',
      'ru':
          '\u042d\u0442\u043e \u043d\u0430\u0432\u0441\u0435\u0433\u0434\u0430 \u0443\u0434\u0430\u043b\u0438\u0442 \u044d\u0442\u043e\u0442 \u0447\u0430\u0442 \u0441 \u0411\u043e\u0431\u043e.',
    },
    'Cancel': {
      'fr': 'Annuler',
      'es': 'Cancelar',
      'hi': '\u0930\u0926\u094d\u0926 \u0915\u0930\u0947\u0902',
      'ru': '\u041e\u0442\u043c\u0435\u043d\u0430',
    },
    'Delete': {
      'fr': 'Supprimer',
      'es': 'Eliminar',
      'hi': '\u0939\u091f\u093e\u090f\u0902',
      'ru': '\u0423\u0434\u0430\u043b\u0438\u0442\u044c',
    },
    'Try again': {
      'fr': 'Réessayer',
      'es': 'Intentar de nuevo',
      'hi':
          '\u092b\u093f\u0930 \u0938\u0947 \u0915\u094b\u0936\u093f\u0936 \u0915\u0930\u0947\u0902',
      'ru':
          '\u041f\u043e\u043f\u0440\u043e\u0431\u043e\u0432\u0430\u0442\u044c \u0441\u043d\u043e\u0432\u0430',
    },
    'Choose your streak goal': {
      'fr': 'Choisissez votre objectif de série',
      'es': 'Elige tu objetivo de racha',
      'hi':
          '\u0905\u092a\u0928\u093e \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u0932\u0915\u094d\u0937\u094d\u092f \u091a\u0941\u0928\u0947\u0902',
      'ru':
          '\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0446\u0435\u043b\u044c \u0441\u0435\u0440\u0438\u0438',
    },
    'Build a learning streak with a goal that feels right for you.': {
      'fr':
          'Cr\u00e9ez une s\u00e9rie d\u2019apprentissage avec un objectif qui vous convient.',
      'es': 'Crea una racha de aprendizaje con un objetivo que te guste.',
      'hi':
          '\u0905\u092a\u0928\u0947 \u0932\u093f\u090f \u0938\u0939\u0940 \u0932\u0915\u094d\u0937\u094d\u092f \u091a\u0941\u0928\u0915\u0930 \u0938\u0940\u0916\u0928\u0947 \u0915\u0940 \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u092c\u0928\u093e\u090f\u0901\u0964',
      'ru':
          '\u0421\u043e\u0437\u0434\u0430\u0439\u0442\u0435 \u0441\u0435\u0440\u0438\u044e \u0437\u0430\u043d\u044f\u0442\u0438\u0439 \u0441 \u043f\u043e\u0434\u0445\u043e\u0434\u044f\u0449\u0435\u0439 \u0432\u0430\u043c \u0446\u0435\u043b\u044c\u044e.',
    },
    '{count} days': {
      'fr': '{count} jours',
      'es': '{count} d\u00edas',
      'hi': '{count} \u0926\u093f\u0928',
      'ru': '{count} \u0434\u043d\u0435\u0439',
    },
    '1 streak freeze': {
      'fr': '1 gel de s\u00e9rie',
      'es': '1 protecci\u00f3n de racha',
      'hi':
          '1 \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u092b\u094d\u0930\u0940\u091c',
      'ru':
          '1 \u0437\u0430\u043c\u043e\u0440\u043e\u0437\u043a\u0430 \u0441\u0435\u0440\u0438\u0438',
    },
    '{count} streak freezes': {
      'fr': '{count} gels de s\u00e9rie',
      'es': '{count} protecciones de racha',
      'hi':
          '{count} \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u092b\u094d\u0930\u0940\u091c',
      'ru':
          '{count} \u0437\u0430\u043c\u043e\u0440\u043e\u0437\u043a\u0438 \u0441\u0435\u0440\u0438\u0438',
    },
    'You earned a Streak Freeze!': {
      'fr': 'Vous avez gagn\u00e9 un gel de s\u00e9rie !',
      'es': '\u00a1Has ganado una protecci\u00f3n de racha!',
      'hi':
          '\u0906\u092a\u0928\u0947 \u090f\u0915 \u0938\u094d\u091f\u0940\u0915 \u092b\u094d\u0930\u0940\u091c \u092a\u093e\u092f\u093e!',
      'ru':
          '\u0412\u044b \u043f\u043e\u043b\u0443\u0447\u0438\u043b\u0438 \u0437\u0430\u043c\u043e\u0440\u043e\u0437\u043a\u0443 \u0441\u0435\u0440\u0438\u0438!',
    },
    '{count} Streak Freezes earned!': {
      'fr': '{count} gels de s\u00e9rie gagn\u00e9s !',
      'es': '\u00a1Has ganado {count} protecciones de racha!',
      'hi':
          '\u0906\u092a\u0928\u0947 {count} \u0938\u094d\u091f\u0940\u0915 \u092b\u094d\u0930\u0940\u091c \u092a\u093e\u090f!',
      'ru':
          '\u0412\u044b \u043f\u043e\u043b\u0443\u0447\u0438\u043b\u0438 {count} \u0437\u0430\u043c\u043e\u0440\u043e\u0437\u043e\u043a \u0441\u0435\u0440\u0438\u0438!',
    },
    'A Streak Freeze automatically protects your streak if you miss a day.': {
      'fr':
          'Un gel de s\u00e9rie prot\u00e8ge automatiquement votre s\u00e9rie si vous manquez une journ\u00e9e.',
      'es':
          'Una protecci\u00f3n de racha protege autom\u00e1ticamente tu racha si te pierdes un d\u00eda.',
      'hi':
          '\u0905\u0917\u0930 \u0906\u092a \u090f\u0915 \u0926\u093f\u0928 \u091a\u0942\u0915 \u091c\u093e\u0924\u0947 \u0939\u0948\u0902, \u0924\u094b \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u092b\u094d\u0930\u0940\u091c \u0906\u092a\u0915\u0940 \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u092c\u091a\u093e\u0924\u093e \u0939\u0948\u0964',
      'ru':
          '\u0417\u0430\u043c\u043e\u0440\u043e\u0437\u043a\u0430 \u0441\u0435\u0440\u0438\u0438 \u0430\u0432\u0442\u043e\u043c\u0430\u0442\u0438\u0447\u0435\u0441\u043a\u0438 \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442 \u0432\u0430\u0448\u0443 \u0441\u0435\u0440\u0438\u044e, \u0435\u0441\u043b\u0438 \u0432\u044b \u043f\u0440\u043e\u043f\u0443\u0441\u0442\u0438\u0442\u0435 \u0434\u0435\u043d\u044c.',
    },
    'Start my goal': {
      'fr': 'Commencer mon objectif',
      'es': 'Iniciar mi objetivo',
      'hi':
          '\u092e\u0947\u0930\u093e \u0932\u0915\u094d\u0937\u094d\u092f \u0936\u0941\u0930\u0942 \u0915\u0930\u0947\u0902',
      'ru':
          '\u041d\u0430\u0447\u0430\u0442\u044c \u043c\u043e\u044e \u0446\u0435\u043b\u044c',
    },
    'Could not save your streak goal.': {
      'fr': 'Impossible d\u2019enregistrer votre objectif de s\u00e9rie.',
      'es': 'No se pudo guardar tu objetivo de racha.',
      'hi':
          '\u0906\u092a\u0915\u093e \u0938\u094d\u091f\u094d\u0930\u0940\u0915 \u0932\u0915\u094d\u0937\u094d\u092f \u0938\u0947\u0935 \u0928\u0939\u0940\u0902 \u0939\u0941\u0906\u0964',
      'ru':
          '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u0446\u0435\u043b\u044c \u0441\u0435\u0440\u0438\u0438.',
    },
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
    'Avatar emoji': {
      'fr': 'Emoji de l’avatar',
      'es': 'Emoji del avatar',
      'hi': 'अवतार इमोजी',
      'ru': 'Эмодзи аватара',
    },
    'Choose an emoji or type one. It can overlap the avatar border.': {
      'fr':
          'Choisissez ou saisissez un emoji. Il peut dépasser du contour de l’avatar.',
      'es': 'Elige o escribe un emoji. Puede sobresalir del borde del avatar.',
      'hi': 'इमोजी चुनें या टाइप करें। यह अवतार की सीमा से बाहर निकल सकता है।',
      'ru': 'Выберите или введите эмодзи. Он может выступать за край аватара.',
    },
    'Type an emoji': {
      'fr': 'Saisissez un emoji',
      'es': 'Escribe un emoji',
      'hi': 'इमोजी टाइप करें',
      'ru': 'Введите эмодзи',
    },
    'Save emoji': {
      'fr': 'Enregistrer l’emoji',
      'es': 'Guardar emoji',
      'hi': 'इमोजी सहेजें',
      'ru': 'Сохранить эмодзи',
    },
    'Remove emoji': {
      'fr': 'Supprimer l’emoji',
      'es': 'Quitar emoji',
      'hi': 'इमोजी हटाएँ',
      'ru': 'Убрать эмодзи',
    },
    'Could not save your avatar emoji.': {
      'fr': 'Impossible d’enregistrer l’emoji de votre avatar.',
      'es': 'No se pudo guardar el emoji del avatar.',
      'hi': 'अवतार इमोजी सहेजा नहीं जा सका।',
      'ru': 'Не удалось сохранить эмодзи аватара.',
    },
    'On': {'fr': 'Activé', 'es': 'Activado', 'hi': 'चालू', 'ru': 'Вкл.'},
    'Off': {'fr': 'Désactivé', 'es': 'Desactivado', 'hi': 'बंद', 'ru': 'Выкл.'},
    'Notifications': {
      'fr': 'Notifications',
      'es': 'Notificaciones',
      'hi': 'Suchnaayein',
      'ru': 'Uvedomleniya',
    },
    'Open': {'fr': 'Ouvrir', 'es': 'Abrir', 'hi': 'Kholein', 'ru': 'Otkryt'},
    'Push reminders': {
      'fr': 'Rappels push',
      'es': 'Recordatorios push',
      'hi': 'Push yaad-dihani',
      'ru': 'Push napominaniya',
    },
    'Daily reminders and learning nudges': {
      'fr': 'Rappels quotidiens',
      'es': 'Recordatorios diarios',
      'hi': 'Rozana seekhne ke yaad-dihani',
      'ru': 'Ezhednevnye napominaniya',
    },
    'Curiosity notifications': {
      'fr': 'Notifications curiosite',
      'es': 'Avisos de curiosidad',
      'hi': 'Jigyasa suchnaayein',
      'ru': 'Uvedomleniya o novom',
    },
    'Quiet hours': {
      'fr': 'Heures calmes',
      'es': 'Horas de silencio',
      'hi': 'Shaant samay',
      'ru': 'Tikhie chasy',
    },
    'From': {'fr': 'De', 'es': 'Desde', 'hi': 'Se', 'ru': 'S'},
    'Until': {'fr': 'Jusqua', 'es': 'Hasta', 'hi': 'Tak', 'ru': 'Do'},
    'Send test notification now': {
      'fr': 'Envoyer un test',
      'es': 'Enviar aviso de prueba',
      'hi': 'Abhi test suchna bhejein',
      'ru': 'Otpravit test',
    },
    'Test notification sent.': {
      'fr': 'Test envoye.',
      'es': 'Aviso de prueba enviado.',
      'hi': 'Test suchna bheji gayi.',
      'ru': 'Test otpravlen.',
    },
    'Test notification and email sent.': {
      'fr': 'Notification et e-mail de test envoyes.',
      'es': 'Notificacion y correo de prueba enviados.',
      'hi': 'Test suchna aur email bheje gaye.',
      'ru': 'Testovoe uvedomlenie i pismo otpravleny.',
    },
    'Test notification sent; email was not sent.': {
      'fr': 'Notification envoyee, mais pas le courriel.',
      'es': 'Se envio la notificacion, pero no el correo.',
      'hi': 'Suchna bheji gayi, email nahi bheja gaya.',
      'ru': 'Uvedomlenie otpravleno, pismo net.',
    },
    'Notifications need Firebase setup and device permission.': {
      'fr': 'Configurez Firebase et autorisez les notifications.',
      'es': 'Configura Firebase y permite las notificaciones.',
      'hi': 'Firebase set karein aur anumati dein.',
      'ru': 'Nastroite Firebase i razreshite uvedomleniya.',
    },
    'Could not load notification preferences.': {
      'fr': 'Impossible de charger les preferences.',
      'es': 'No se pudieron cargar las preferencias.',
      'hi': 'Suchna pasand load nahi hui.',
      'ru': 'Ne udalos zagruzit nastroyki.',
    },
    'Could not save notification preferences.': {
      'fr': 'Impossible denregistrer les preferences.',
      'es': 'No se pudieron guardar las preferencias.',
      'hi': 'Suchna pasand save nahi hui.',
      'ru': 'Ne udalos sohranit nastroyki.',
    },
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
