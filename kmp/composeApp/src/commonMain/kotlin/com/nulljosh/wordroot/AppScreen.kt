package com.nulljosh.wordroot

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@Composable
fun WordrootTheme(content: @Composable () -> Unit) =
    MaterialTheme(colorScheme = lightColorScheme(), content = content)

// ponytail: word language fixed to English for this pass, no UI-language
// picker (the web app has 12 interface x 30 word languages). definitions +
// etymology logic is real, not a stub.
@Composable
fun AppScreen(client: WiktionaryClient = WiktionaryClient()) {
    var query by remember { mutableStateOf("") }
    var definitions by remember { mutableStateOf<Definitions?>(null) }
    var chain by remember { mutableStateOf<List<EtymologyStep>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    fun lookup() {
        val word = query.trim()
        if (word.isEmpty()) return
        scope.launch {
            loading = true
            definitions = client.definitions(word, "en")
            chain = client.etymology(word, "en")
            status = if (definitions == null && chain.isEmpty()) "No results for \"$word\"." else ""
            loading = false
        }
    }

    Surface {
        Column(Modifier.fillMaxSize().padding(24.dp)) {
            Text("Wordroot", style = MaterialTheme.typography.headlineMedium)
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("Word") },
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            )
            Button(onClick = { lookup() }, modifier = Modifier.padding(top = 8.dp)) { Text("Look up") }
            if (loading) CircularProgressIndicator(Modifier.padding(top = 16.dp))
            if (status.isNotEmpty()) Text(status, modifier = Modifier.padding(top = 16.dp))
            definitions?.groups?.forEach { group ->
                Text(group.partOfSpeech, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
                group.defs.forEach { Text("- $it") }
            }
            if (chain.isNotEmpty()) {
                Text("Etymology", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
                chain.forEach { step ->
                    Text("${step.ancestor} (${step.language}) - ${step.relation}")
                }
            }
        }
    }
}
