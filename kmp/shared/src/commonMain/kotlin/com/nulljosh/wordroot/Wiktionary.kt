package com.nulljosh.wordroot

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

data class DefinitionGroup(val partOfSpeech: String, val defs: List<String>)
data class Definitions(val edition: String, val groups: List<DefinitionGroup>)
data class EtymologyStep(val relation: String, val langCode: String, val language: String, val ancestor: String)

private val HTML_TAG = Regex("<[^>]+>")

private fun strip(html: String): String = html.replace(HTML_TAG, "").trim()

private val REL_LABEL = mapOf("inh" to "inherited from", "der" to "derived from", "bor" to "borrowed from")

private val LINK_RE = Regex("""\{\{(inh\+?|der\+?|bor\+?)\|[^|]*\|([^|}]+)\|([^|}]*)""")

/** Ported from web/index.html's definitionsFrom/definitions/etymology/languageSection. Two
 *  Wiktionary REST/API calls: the per-word REST definition endpoint (per edition, in
 *  preference order) and the raw wikitext of the English edition for etymology, which is the
 *  only edition whose inh/der/bor templates this parser understands. */
class WiktionaryClient {
    private val http = HttpClient {
        install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
    }

    private val noDefinitionEndpoint = mutableSetOf<String>()

    private suspend fun definitionsFrom(edition: String, word: String, lang: String): Definitions? {
        if (edition in noDefinitionEndpoint) return null
        val response: JsonObject = try {
            http.get("https://$edition.wiktionary.org/api/rest_v1/page/definition/${word.encodeUrl()}").body()
        } catch (e: Exception) {
            noDefinitionEndpoint.add(edition)
            return null
        }
        val entries = response[lang] as? JsonArray ?: return null
        if (entries.isEmpty()) return null
        val groups = entries.mapNotNull { entry ->
            val obj = entry.jsonObject
            val pos = obj["partOfSpeech"]?.jsonPrimitive?.content ?: return@mapNotNull null
            val defsArr = obj["definitions"] as? JsonArray ?: return@mapNotNull null
            val defs = defsArr.mapNotNull { d ->
                strip(d.jsonObject["definition"]?.jsonPrimitive?.content ?: "").ifBlank { null }
            }.take(4)
            if (defs.isEmpty()) null else DefinitionGroup(pos, defs)
        }
        return if (groups.isEmpty()) null else Definitions(edition, groups)
    }

    /** Preference order: the reader's edition first, then English as backstop. */
    suspend fun definitions(word: String, wordLangCode: String): Definitions? {
        val editions = if (wordLangCode == "en") listOf("en") else listOf(wordLangCode, "en")
        for (edition in editions) {
            definitionsFrom(edition, word, wordLangCode)?.let { return it }
        }
        return null
    }

    suspend fun etymology(word: String, wordLangCode: String): List<EtymologyStep> {
        val meta = wordLanguage(wordLangCode) ?: return emptyList()
        val response: JsonObject = try {
            http.get("https://en.wiktionary.org/w/api.php") {
                parameter("action", "parse")
                parameter("page", word)
                parameter("prop", "wikitext")
                parameter("format", "json")
                parameter("origin", "*")
            }.body()
        } catch (e: Exception) {
            return emptyList()
        }
        val wikitext = response["parse"]?.jsonObject?.get("wikitext")?.jsonObject?.get("*")?.jsonPrimitive?.content
            ?: return emptyList()
        val section = languageSection(wikitext, meta.section) ?: return emptyList()
        val etymBlock = etymologyBlock(section) ?: return emptyList()

        val chain = mutableListOf<EtymologyStep>()
        for (m in LINK_RE.findAll(etymBlock)) {
            val rel = m.groupValues[1].removeSuffix("+")
            val langCode = m.groupValues[2]
            val ancestor = m.groupValues[3]
            val label = REL_LABEL[rel]
            if (label != null && ancestor.isNotBlank()) {
                chain.add(EtymologyStep(label, langCode, wordLanguage(langCode)?.english ?: langCode, ancestor))
            }
            if (chain.size >= 10) break
        }
        return chain
    }
}

/** Body of the `==Name==` language section, stopping at the next level-2 heading. */
fun languageSection(text: String, name: String): String? {
    val headingRe = Regex("^==\\s*${Regex.escape(name)}\\s*==\\s*$", RegexOption.MULTILINE)
    val m = headingRe.find(text) ?: return null
    val after = text.substring(m.range.last + 1)
    val endRe = Regex("^==[^=]", RegexOption.MULTILINE)
    val end = endRe.find(after)?.range?.first
    return if (end == null) after else after.substring(0, end)
}

private val ETYMOLOGY_RE = Regex("===?Etymology[^=]*===?\\n([\\s\\S]*?)(\\n===?[^=]|$)")

fun etymologyBlock(section: String): String? = ETYMOLOGY_RE.find(section)?.groupValues?.get(1)

private fun String.encodeUrl(): String = buildString {
    for (c in this@encodeUrl) {
        if (c.isLetterOrDigit() || c in "-_.~") append(c) else {
            for (b in c.toString().encodeToByteArray()) append("%${b.toInt().and(0xFF).toString(16).padStart(2, '0').uppercase()}")
        }
    }
}
