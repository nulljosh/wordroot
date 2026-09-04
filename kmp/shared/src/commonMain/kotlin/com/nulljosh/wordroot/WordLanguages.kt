package com.nulljosh.wordroot

// Ported from i18n/strings.json's wordLanguages table.
data class WordLanguage(val code: String, val section: String, val english: String)

val WORD_LANGUAGES: List<WordLanguage> = listOf(
    WordLanguage("en", "English", "English"),
    WordLanguage("es", "Spanish", "Spanish"),
    WordLanguage("fr", "French", "French"),
    WordLanguage("de", "German", "German"),
    WordLanguage("pt", "Portuguese", "Portuguese"),
    WordLanguage("it", "Italian", "Italian"),
    WordLanguage("nl", "Dutch", "Dutch"),
    WordLanguage("ru", "Russian", "Russian"),
    WordLanguage("ja", "Japanese", "Japanese"),
    WordLanguage("zh", "Chinese", "Chinese"),
    WordLanguage("ko", "Korean", "Korean"),
    WordLanguage("ar", "Arabic", "Arabic"),
    WordLanguage("he", "Hebrew", "Hebrew"),
    WordLanguage("fa", "Persian", "Persian"),
    WordLanguage("hi", "Hindi", "Hindi"),
    WordLanguage("tr", "Turkish", "Turkish"),
    WordLanguage("pl", "Polish", "Polish"),
    WordLanguage("sv", "Swedish", "Swedish"),
    WordLanguage("da", "Danish", "Danish"),
    WordLanguage("no", "Norwegian", "Norwegian"),
    WordLanguage("fi", "Finnish", "Finnish"),
    WordLanguage("is", "Icelandic", "Icelandic"),
    WordLanguage("ga", "Irish", "Irish"),
    WordLanguage("cy", "Welsh", "Welsh"),
    WordLanguage("el", "Greek", "Greek"),
    WordLanguage("la", "Latin", "Latin"),
    WordLanguage("grc", "Ancient Greek", "Ancient Greek"),
    WordLanguage("sa", "Sanskrit", "Sanskrit"),
    WordLanguage("ang", "Old English", "Old English"),
    WordLanguage("non", "Old Norse", "Old Norse"),
)

fun wordLanguage(code: String): WordLanguage? = WORD_LANGUAGES.find { it.code == code }
