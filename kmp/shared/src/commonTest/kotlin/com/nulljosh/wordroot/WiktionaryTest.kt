package com.nulljosh.wordroot

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class WiktionaryTest {
    private val sampleWikitext = """
        ==French==

        ===Etymology===
        Inherited from {{inh|fr|fro|chat}}, from {{inh|fro|la|cattus}}.

        ===Noun===
        {{fr-noun}}

        # cat

        ==English==

        ===Etymology===
        {{bor|en|fro|chat}}, borrowed later.

        ===Noun===
        # a domestic feline
    """.trimIndent()

    @Test fun languageSectionScopesToOneLanguage() {
        val french = languageSection(sampleWikitext, "French")!!
        assertTrue(french.contains("cattus"))
        assertTrue(!french.contains("domestic feline"))

        val english = languageSection(sampleWikitext, "English")!!
        assertTrue(english.contains("domestic feline"))
        assertTrue(!english.contains("cattus"))
    }

    @Test fun missingLanguageSectionIsNull() {
        assertNull(languageSection(sampleWikitext, "German"))
    }

    @Test fun etymologyBlockExtractsInhDerBor() {
        val french = languageSection(sampleWikitext, "French")!!
        val block = etymologyBlock(french)!!
        assertTrue(block.contains("{{inh|fr|fro|chat}}"))
        assertTrue(block.contains("{{inh|fro|la|cattus}}"))
    }

    @Test fun wordLanguageTableHas30Entries() {
        assertEquals(30, WORD_LANGUAGES.size)
        assertEquals("French", wordLanguage("fr")?.section)
    }
}
